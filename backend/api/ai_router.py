# api/ai_router.py

from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from pydantic import BaseModel
from supabase import Client
from typing import List, Optional
import datetime

# Our project imports
from dependencies import get_supabase_client, get_current_user
from services.gemini_service import get_ai_response
from services.memory_service import construct_memory_stream
from services.background_tasks import update_token_count_task
from core.personas import EXPERT_PERSONAS

# Create an APIRouter instance
router = APIRouter()

# --- Pydantic Models ---
class AIInteractionRequest(BaseModel):
    # user_id is REMOVED. We get it from the token.
    agent_name: str
    message: str

class AIInteractionResponse(BaseModel):
    response: str
    agent_name: str
    timestamp: datetime.datetime

# --- Helper Function ---
def format_db_history_for_gemini(db_history: list) -> list:
    """
    Converts conversation history from the Supabase format to the Gemini format.
    """
    gemini_history = []
    for interaction in db_history:
        gemini_history.append({'role': 'user', 'parts': [interaction['user_message']]})
        gemini_history.append({'role': 'model', 'parts': [interaction['ai_response']]})
    return gemini_history

# --- Pydantic model for a unified timeline item ---
class AgentTimelineItem(BaseModel):
    item_id: str
    item_type: str
    user_message: Optional[str] = None
    ai_response: Optional[str] = None
    created_at: datetime.datetime
    entry_id: Optional[str] = None
    journal_content: Optional[str] = None

# --- Paginated Agent Timeline Endpoint ---
@router.get(
    "/ai/timeline/{agent_name}",
    response_model=List[AgentTimelineItem],
    summary="Get Paginated Unified Timeline for an Agent"
)
def get_agent_timeline(
    agent_name: str,
    page: int = 0,
    page_size: int = 20,
    current_user = Depends(get_current_user), # <-- PROTECTED
    supabase: Client = Depends(get_supabase_client)
):
    """
    Calls the get_agent_timeline_page database function to fetch the unified timeline.
    """
    try:
        user_id = current_user.user.id # <-- Get user_id from the validated token
        params = {
            "user_uuid": user_id,
            "agent_name_param": agent_name,
            "page_size": page_size,
            "page_number": page
        }
        res = supabase.rpc("get_agent_timeline_page", params).execute()
        return res.data
    except Exception as e:
        print(f"ERROR fetching agent timeline: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch agent timeline.")

# --- The Main Interaction Endpoint ---
@router.post(
    "/ai/interact",
    response_model=AIInteractionResponse,
    summary="Interact with an AI Agent (Scalable Memory)"
)
def interact_with_ai(
    request: AIInteractionRequest,
    background_tasks: BackgroundTasks,
    current_user = Depends(get_current_user), # <-- PROTECTED
    supabase: Client = Depends(get_supabase_client)
):
    user_id = current_user.user.id # <-- Get user_id from the validated token

    if request.agent_name not in EXPERT_PERSONAS:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"AI Agent '{request.agent_name}' not found."
        )
    
    print(f"Request received for agent '{request.agent_name}' from user '{user_id}'")
    persona = EXPERT_PERSONAS[request.agent_name]

    chat_history_for_gemini = construct_memory_stream(user_id, request.agent_name, supabase)

    ai_response_text = get_ai_response(
        persona_prompt=persona,
        user_message=request.message,
        chat_history=chat_history_for_gemini,
        user_id_for_debug=user_id,
        agent_name_for_debug=request.agent_name
    )

    try:
        supabase.table("ai_interactions").insert({
            "user_id": user_id,
            "agent_name": request.agent_name,
            "user_message": request.message,
            "ai_response": ai_response_text
        }).execute()
        print("Interaction logged successfully.")

        background_tasks.add_task(
            update_token_count_task,
            user_id=user_id,
            agent_name=request.agent_name,
            new_interaction={"user_message": request.message, "ai_response": ai_response_text},
            supabase=supabase
        )

    except Exception as e:
        print(f"CRITICAL WARNING: Failed to log interaction or trigger background tasks. Error: {e}")

    return AIInteractionResponse(
        response=ai_response_text,
        agent_name=request.agent_name,
        timestamp=datetime.datetime.now()
    )