# api/journal_router.py

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from supabase import Client
import httpx  # A modern, async-friendly HTTP client library

# Our project imports
from dependencies import get_supabase_client

router = APIRouter()

# --- Pydantic Models ---
class JournalEntryRequest(BaseModel):
    user_id: str
    content: str

# --- Configuration for XP Reward ---
# It's a best practice to keep configurable values like this in one place.
XP_AWARD_FOR_JOURNAL_ENTRY = 15

# --- The Endpoint ---
@router.post(
    "/journal/add",
    summary="Add a new journal entry",
    description="Saves a user's journal entry to the database and awards them XP."
)
async def add_journal_entry(
    request: JournalEntryRequest,
    supabase: Client = Depends(get_supabase_client)
):
    """
    Handles saving a new journal entry.
    1. Saves the content to the 'journal_entries' table.
    2. On success, makes an internal call to the 'award-xp' endpoint.
    """
    # 1. --- Save the journal entry ---
    try:
        print(f"Saving journal entry for user: {request.user_id}")
        insert_res = supabase.table("journal_entries").insert({
            "user_id": request.user_id,
            "content": request.content
        }).execute()

        # The Supabase python client v1 returns a list in 'data'. If it's empty, something went wrong.
        if not insert_res.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to save journal entry to the database."
            )
        
        print("Journal entry saved successfully.")

    except Exception as e:
        print(f"ERROR: Could not save journal entry. Error: {e}")
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred while saving the entry: {str(e)}"
        )

    # 2. --- Award XP via internal API call ---
    # Why do this instead of just calling the function?
    # This keeps our services decoupled. The journal service doesn't need to know
    # the implementation details of the XP system. It just knows there's an endpoint for it.
    # This makes the system more modular and easier to maintain.
    try:
        # We use an async HTTP client for this server-to-server call.
        async with httpx.AsyncClient() as client:
            # The URL for our running FastAPI application
            # NOTE: This assumes the server is running on localhost:8000
            xp_award_url = "http://127.0.0.1:8000/api/user/award-xp"
            xp_payload = {
                "user_id": request.user_id,
                "amount": XP_AWARD_FOR_JOURNAL_ENTRY,
                "event_name": "journal_entry_added"
            }
            
            print(f"Making internal call to award {XP_AWARD_FOR_JOURNAL_ENTRY} XP...")
            response = await client.post(xp_award_url, json=xp_payload)
            
            # This will raise an exception if the status code is 4xx or 5xx
            response.raise_for_status()
            
            print("XP awarded successfully via internal API call.")

    except httpx.HTTPStatusError as e:
        # This is a critical warning. The user saved their journal but didn't get XP.
        # In a production system, you might log this for manual correction or use a retry mechanism.
        print(f"CRITICAL WARNING: Journal entry was saved, but failed to award XP. Status: {e.response.status_code}, Response: {e.response.text}")
        # We don't raise an exception here because the main action (saving the journal) was successful.
        # It's better to return success to the user.

    return {"status": "success", "message": "Journal entry saved and XP awarded."}