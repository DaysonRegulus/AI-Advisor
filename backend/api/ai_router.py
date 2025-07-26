# api/ai_router.py

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from supabase import Client
import datetime

# Our project imports
from dependencies import get_supabase_client
from services.gemini_service import get_ai_response
from core.personas import EXPERT_PERSONAS

# Create an APIRouter instance. This is like a mini-FastAPI app.
router = APIRouter()

# --- Pydantic Models for Data Validation ---
class AIInteractionRequest(BaseModel):
    agent_name: str
    message: str
    user_id: str  # In a real app, you'd get this from a JWT token. For now, we pass it manually.

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

# --- The Main Endpoint ---
@router.post(
    "/ai/interact",
    response_model=AIInteractionResponse,
    summary="Interact with an AI Agent",
    description="Sends a message to a specific AI agent and gets a response, maintaining chat history."
)
def interact_with_ai(
    request: AIInteractionRequest,
    supabase: Client = Depends(get_supabase_client)
):
    """
    Handles the core logic for AI agent interaction.
    1. Validates the agent name.
    2. Fetches recent conversation history from Supabase for context.
    3. Calls the Gemini service to get a new response.
    4. Logs the new interaction to Supabase.
    """
    # 1. --- Validate Agent Name ---
    if request.agent_name not in EXPERT_PERSONAS:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"AI Agent '{request.agent_name}' not found."
        )
    
    print(f"Request received for agent '{request.agent_name}' from user '{request.user_id}'")
    persona = EXPERT_PERSONAS[request.agent_name]

    # 2. --- Fetch Conversation History (The "Memory") ---
    chat_history_for_gemini = []
    try:
        print("Fetching chat history from Supabase...")
        # Fetch the last 10 turns (5 user, 5 model) of conversation for this specific agent.
        # Sorting by 'created_at' ascending ensures we get the history in the correct order.
        history_response = supabase.table("ai_interactions").select("user_message, ai_response") \
            .eq("user_id", request.user_id) \
            .eq("agent_name", request.agent_name) \
            .order("created_at", desc=False) \
            .limit(10) \
            .execute()
        
        if history_response.data:
            print(f"Found {len(history_response.data)} previous interactions.")
            chat_history_for_gemini = format_db_history_for_gemini(history_response.data)
        else:
            print("No previous chat history found for this agent.")

    except Exception as e:
        # If fetching history fails, we can still proceed without it.
        # Log the error but don't block the user's interaction.
        print(f"Warning: Could not fetch chat history. Proceeding without it. Error: {e}")

    # 3. --- Get AI Response from Gemini Service ---
    ai_response_text = get_ai_response(
        persona_prompt=persona,
        user_message=request.message,
        chat_history=chat_history_for_gemini
    )

    # 4. --- Log the New Interaction to Supabase ---
    try:
        print("Logging new interaction to Supabase...")
        supabase.table("ai_interactions").insert({
            "user_id": request.user_id,
            "agent_name": request.agent_name,
            "user_message": request.message,
            "ai_response": ai_response_text
        }).execute()
        print("Interaction logged successfully.")
    except Exception as e:
        # This is more critical. We should at least log it prominently.
        # In a production system, you might add this to a retry queue.
        print(f"CRITICAL WARNING: Failed to log AI interaction to Supabase for user {request.user_id}. Error: {e}")
        # We don't raise an HTTPException because the user has already received their response.
        # Failing silently on the log is better than returning an error to the user at this stage.

    # 5. --- Return the Final Response ---
    return AIInteractionResponse(
        response=ai_response_text,
        agent_name=request.agent_name,
        timestamp=datetime.datetime.now()
    )