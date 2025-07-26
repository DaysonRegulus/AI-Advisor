# api/overseer_router.py

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from supabase import Client
import datetime

# Our project imports
from dependencies import get_supabase_client
from services.overseer_service import generate_daily_summary_for_user

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
    
    # Call the service that contains all the complex logic
    summary_text = generate_daily_summary_for_user(request.user_id, supabase)

    if not summary_text:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No recent user activity found to generate a summary."
        )
    
    # Save the generated summary to the database
    try:
        # Using 'upsert' is a great practice here.
        # It will INSERT a new row, but if a row for that user and date already
        # exists, it will UPDATE it instead. This prevents duplicate summaries.
        supabase.table("daily_summaries").upsert({
            "user_id": request.user_id,
            "summary_text": summary_text,
            "date": str(today) # Make sure to cast date to string
        },
        on_conflict="user_id,date"  # <-- THIS IS THE FIX
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