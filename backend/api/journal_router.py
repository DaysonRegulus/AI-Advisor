# api/journal_router.py

from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from pydantic import BaseModel
from supabase import Client
import asyncio

# Our project imports
from dependencies import get_supabase_client
from services.gemini_service import get_ai_response
from services.memory_service import construct_memory_stream
from core.personas import EXPERT_PERSONAS

router = APIRouter()

# --- Data Models ---
class JournalEntryRequest(BaseModel):
    user_id: str
    content: str

class JournalEntryResponse(BaseModel):
    id: str
    user_id: str
    content: str
    created_at: str

class AIComment(BaseModel):
    agent_name: str
    comment_text: str

# --- Background Task for Generating Comments ---

async def generate_and_save_comments(entry_id: str, entry_content: str, user_id: str, supabase: Client):
    """
    This function runs in the background. It gets comments from all agents and saves them.
    """
    print(f"BACKGROUND TASK: Started comment generation for entry_id: {entry_id}")

    # The prompt for the comment generation
    comment_prompt = f"""
    Based on your specific role and your entire memory of this user, please analyze the following journal entry written by them.
    
    Journal Entry: "{entry_content}"

    Provide a brief, encouraging, and insightful comment (1-3 sentences). Your comment should be directly actionable or promote self-reflection.
    If the entry is entirely irrelevant to your domain of expertise, you MUST respond with only the exact text 'NO_COMMENT' and nothing else.
    """

    # Prepare concurrent tasks for all agents
    tasks = []
    agents_to_query = [name for name in EXPERT_PERSONAS if name != "master_overseer"]

    for agent_name in agents_to_query:
        # We create a coroutine for each agent call
        task = get_single_agent_comment(agent_name, comment_prompt, user_id, supabase)
        tasks.append(task)
    
    # Run all API calls concurrently
    results = await asyncio.gather(*tasks, return_exceptions=True)
    
    valid_comments = []
    for agent_name, result in zip(agents_to_query, results):
        if isinstance(result, Exception):
            print(f"Error getting comment from {agent_name}: {result}")
        elif result and result.strip() != "NO_COMMENT":
            valid_comments.append({
                "entry_id": entry_id,
                "agent_name": agent_name,
                "comment_text": result.strip()
            })
    
    # Save valid comments to a new database table
    if valid_comments:
        try:
            # We need a new table: 'journal_comments'
            supabase.table("journal_comments").insert(valid_comments).execute()
            print(f"BACKGROUND TASK: Successfully saved {len(valid_comments)} comments for entry {entry_id}.")
        except Exception as e:
            print(f"BACKGROUND TASK ERROR: Could not save comments to database. Error: {e}")

async def get_single_agent_comment(agent_name: str, prompt: str, user_id: str, supabase: Client) -> str:
    """Helper coroutine to get a comment from one agent."""
    persona = EXPERT_PERSONAS[agent_name]
    memory = construct_memory_stream(user_id, agent_name, supabase)
    response = get_ai_response(
        persona_prompt=persona,
        user_message=prompt,
        chat_history=memory
    )
    return response

# --- API Endpoints ---

@router.post("/journal/add", response_model=JournalEntryResponse, status_code=status.HTTP_201_CREATED)
async def add_journal_entry(
    request: JournalEntryRequest,
    background_tasks: BackgroundTasks,
    supabase: Client = Depends(get_supabase_client)
):
    """
    Saves a journal entry and triggers AI comment generation in the background.
    """
    try:
        insert_res = supabase.table("journal_entries").insert({
            "user_id": request.user_id,
            "content": request.content
        }).execute()
        
        if not insert_res.data:
            raise HTTPException(status_code=500, detail="Failed to save journal entry.")
        
        new_entry = insert_res.data[0]
        
        # Add the comment generation task to run in the background after the response is sent
        background_tasks.add_task(
            generate_and_save_comments,
            entry_id=new_entry['id'],
            entry_content=new_entry['content'],
            user_id=new_entry['user_id'],
            supabase=supabase
        )
        
        # Immediately return the created journal entry to the user
        return new_entry

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/journal/comments/{entry_id}", response_model=List[AIComment])
async def get_journal_comments(entry_id: str, supabase: Client = Depends(get_supabase_client)):
    """
    Fetches all saved AI comments for a specific journal entry.
    """
    try:
        res = supabase.table("journal_comments").select("agent_name, comment_text").eq("entry_id", entry_id).execute()
        return res.data
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))