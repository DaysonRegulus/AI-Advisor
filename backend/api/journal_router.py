# api/journal_router.py

from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from core.connection_manager import manager as ws_manager 
from pydantic import BaseModel
from supabase import Client
import asyncio
import json
from typing import List, Dict, Any, Optional

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
    created_at: str
    entry_id: str

class TimelineItem(BaseModel):
    item_id: str
    item_type: str
    content: str
    created_at: str
    agent_name: Optional[str] = None
    entry_id: Optional[str] = None

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
    for comment in valid_comments:
        try:
            # 1. Save the comment to the database
            db_response = supabase.table("journal_comments").insert(comment).execute()
        
            # 2. If saving was successful, push it to the client
            if db_response.data:
                print(f"Successfully saved comment from {comment['agent_name']} to DB.")
            
                # The message must be a JSON string.
                # We also need to add the entry_id so the client knows which journal this comment belongs to.
                payload = {
                    "entry_id": entry_id,
                    "agent_name": comment['agent_name'],
                    "comment_text": comment['comment_text']
                }
                await ws_manager.send_personal_message(payload, user_id)
        
        except Exception as e:
            print(f"BACKGROUND TASK ERROR: Could not process/send comment from {comment['agent_name']}. Error: {e}")

    print(f"BACKGROUND TASK: Finished comment generation for entry {entry_id}.")

async def get_single_agent_comment(agent_name: str, prompt: str, user_id: str, supabase: Client) -> str:
    """Helper coroutine that runs blocking AI calls in a separate thread."""
    def blocking_ai_call():
        # This inner function contains all the synchronous code
        persona = EXPERT_PERSONAS[agent_name]
        # Note: We pass the debug info here as well now
        memory = construct_memory_stream(user_id, agent_name, supabase)
        response = get_ai_response(
            persona_prompt=persona,
            user_message=prompt,
            chat_history=memory,
            user_id_for_debug=user_id,
            agent_name_for_debug=f"{agent_name}_journal_comment" # Make debug name specific
        )
        return response

    # Use asyncio.to_thread to run the blocking function without stalling the event loop
    loop = asyncio.get_running_loop()
    response_text = await loop.run_in_executor(None, blocking_ai_call)
    return response_text

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
    
@router.get("/journal/timeline", response_model=List[TimelineItem])
async def get_journal_timeline(
    user_id: str,
    page: int = 0,
    page_size: int = 20, # A sensible default page size
    supabase: Client = Depends(get_supabase_client)
):
    """
    Fetches a paginated, chronologically sorted list of all journal items
    (entries and comments) by calling a database function.
    """
    try:
        params = {"user_uuid": user_id, "page_size": page_size, "page_number": page}
        res = supabase.rpc("get_user_timeline_page", params).execute()
        return res.data
    except Exception as e:
        print(f"ERROR fetching timeline page: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch journal timeline.")