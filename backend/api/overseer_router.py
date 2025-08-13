# api/overseer_router.py

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from supabase import Client
import datetime

# Our project imports
from dependencies import get_supabase_client
from services.memory_service import construct_memory_stream
from services.gemini_service import get_ai_response
from core.personas import EXPERT_PERSONAS

router = APIRouter()

# --- Pydantic Models ---
class SummaryRequest(BaseModel):
    user_id: str

# --- The Endpoint ---
@router.post(
    "/overseer/generate-summary",
    summary="Generate and Save a Daily Summary",
    description="Triggers the Master Overseer to analyze the user's recent activity and save a summary."
)
def trigger_summary_generation(
    request: SummaryRequest,
    supabase: Client = Depends(get_supabase_client)
):
    today = datetime.datetime.utcnow().date()
    agent_name = "master_overseer"

    print(f"--- Triggering Daily Summary Generation for user: {request.user_id} ---")

    # 1. Construct the complete memory stream for the Overseer
    overseer_memory = construct_memory_stream(request.user_id, agent_name, supabase)

    # 2. Define the task prompt for today's summary
    summary_task_prompt = """
    Analyze all the provided context (your past summaries, user journals, and all agent conversations) and generate a new, concise, one-paragraph daily summary for today. 
    Focus on the user's emotional state, key accomplishments, and any emerging patterns or conflicts between different life domains. 
    Your tone should be insightful, encouraging, and forward-looking.
    """

    # 3. Call the central Gemini service
    summary_text = get_ai_response(
        persona_prompt=EXPERT_PERSONAS[agent_name],
        user_message=summary_task_prompt,
        chat_history=overseer_memory,
        user_id_for_debug=request.user_id,
        agent_name_for_debug=agent_name
    )

    if not summary_text or "Error: The AI service is not configured" in summary_text:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="The AI service failed to generate a summary."
        )

    # 4. Save the new summary to the database (This part now uses your existing, correct logic)
    try:
        supabase.table("daily_summaries").upsert(
            {
                "user_id": request.user_id,
                "summary_text": summary_text,
                "date": str(today)
            },
            on_conflict="user_id,date"  # Preserving your important fix
        ).execute()
        print(f"Successfully saved daily summary for user {request.user_id} on {today}")

    except Exception as e:
        print(f"CRITICAL ERROR: Failed to save daily summary to database. Error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"AI summary was generated, but failed to save to the database. {e}"
        )
    
    return {"status": "success", "message": "Daily summary generated and saved."}

@router.get(
    "/overseer/latest-summary/{user_id}",
    summary="Fetch Latest Daily Summary",
    description="Retrieves the most recent daily summary for a given user."
)
def get_latest_summary(user_id: str, supabase: Client = Depends(get_supabase_client)):
    try:
        res = supabase.table("daily_summaries") \
            .select("*") \
            .eq("user_id", user_id) \
            .order("date", desc=True) \
            .limit(1) \
            .single() \
            .execute()
        return res.data
    except Exception as e:
        # .single() will throw an error if no row is found, which is expected.
        print(f"No summary found for user {user_id}. Error: {e}")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No daily summary found for this user."
        )