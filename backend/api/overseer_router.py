# api/overseer_router.py

from fastapi import APIRouter, Depends, HTTPException, status
from supabase import Client
import datetime

# Our project imports
from dependencies import get_supabase_client, get_current_user
from services.memory_service import construct_memory_stream
from services.gemini_service import get_ai_response
from core.personas import EXPERT_PERSONAS

router = APIRouter()

@router.post(
    "/overseer/generate-summary",
    summary="Generate and Save a Daily Summary"
)
def trigger_summary_generation(
    current_user = Depends(get_current_user), # <-- PROTECTED
    supabase: Client = Depends(get_supabase_client)
):
    user_id = current_user.user.id # <-- Get user_id from the validated token
    today = datetime.datetime.utcnow().date()
    agent_name = "master_overseer"

    print(f"--- Triggering Daily Summary Generation for user: {user_id} ---")

    overseer_memory = construct_memory_stream(user_id, agent_name, supabase)

    summary_task_prompt = """
    Analyze all the provided context (your past summaries, user journals, and all agent conversations) and generate a new, concise, one-paragraph daily summary for today. 
    Focus on the user's emotional state, key accomplishments, and any emerging patterns or conflicts between different life domains. 
    Your tone should be insightful, encouraging, and forward-looking.
    """

    summary_text = get_ai_response(
        persona_prompt=EXPERT_PERSONAS[agent_name],
        user_message=summary_task_prompt,
        chat_history=overseer_memory,
        user_id_for_debug=user_id,
        agent_name_for_debug=agent_name
    )

    if not summary_text or "Error: The AI service is not configured" in summary_text:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="The AI service failed to generate a summary."
        )
    try:
        supabase.table("daily_summaries").upsert(
            {
                "user_id": user_id,
                "summary_text": summary_text,
                "date": str(today)
            },
            on_conflict="user_id,date"
        ).execute()
        print(f"Successfully saved daily summary for user {user_id} on {today}")

    except Exception as e:
        print(f"CRITICAL ERROR: Failed to save daily summary to database. Error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"AI summary was generated, but failed to save to the database. {e}"
        )
    
    return {"status": "success", "message": "Daily summary generated and saved."}

@router.get(
    "/overseer/latest-summary", # Removed {user_id} from path
    summary="Fetch Latest Daily Summary"
)
def get_latest_summary(
    current_user = Depends(get_current_user), # <-- PROTECTED
    supabase: Client = Depends(get_supabase_client)
):
    user_id = current_user.user.id # <-- Get user_id from the validated token
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
        print(f"No summary found for user {user_id}. Error: {e}")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No daily summary found for this user."
        )