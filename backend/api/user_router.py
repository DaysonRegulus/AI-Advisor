# api/user_router.py

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from supabase import Client
from typing import Optional

# Our project imports
from dependencies import get_supabase_client, get_current_user

router = APIRouter()

# --- Helper Function for XP Calculation ---
def calculate_next_level_xp(level: int) -> int:
    return int(100 * (level ** 1.5))

# --- Pydantic Models ---
class AwardXpRequest(BaseModel):
    # user_id is REMOVED from the request body
    amount: int = Field(..., gt=0)
    event_name: str

class UserProfileResponse(BaseModel):
    user_id: str
    username: Optional[str] = None
    level: int
    xp_points: int
    xp_to_next_level: int
    leveled_up: bool

@router.post(
    "/user/award-xp",
    response_model=UserProfileResponse,
    summary="Award Experience Points to the Current User"
)
def award_xp(
    request: AwardXpRequest,
    current_user=Depends(get_current_user), # <-- PROTECTED
    supabase: Client = Depends(get_supabase_client)
):
    user_id = current_user.user.id # <-- Get user_id from the validated token
    try:
        profile_res = supabase.table("user_profiles").select("*").eq("id", user_id).single().execute()
        
        if not profile_res.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"User profile not found for user_id: {user_id}"
            )
        
        profile = profile_res.data
        leveled_up = False
        new_xp = profile['xp_points'] + request.amount
        current_level = profile['level']
        xp_for_next = profile['xp_to_next_level']

        while new_xp >= xp_for_next:
            leveled_up = True
            current_level += 1
            new_xp -= xp_for_next
            xp_for_next = calculate_next_level_xp(current_level)
        
        update_response = supabase.table("user_profiles").update({
            "level": current_level,
            "xp_points": new_xp,
            "xp_to_next_level": xp_for_next,
        }).eq("id", profile['id']).execute()
        
        if not update_response.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to update user profile in the database."
            )

        return UserProfileResponse(
            user_id=profile['id'],
            username=profile.get('username'),
            level=current_level,
            xp_points=new_xp,
            xp_to_next_level=xp_for_next,
            leveled_up=leveled_up
        )
    except Exception as e:
        if isinstance(e, HTTPException): raise e
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred while awarding XP: {str(e)}"
        )
        
@router.get(
    "/user/profile",
    response_model=UserProfileResponse,
    summary="Get Current User's Profile"
)
def get_user_profile(
    current_user = Depends(get_current_user),
    supabase: Client = Depends(get_supabase_client)
):
    user_id = current_user.user.id
    try:
        profile_res = supabase.table("user_profiles").select("*").eq("id", user_id).single().execute()
        profile = profile_res.data
        
        response_data = {
            "user_id": profile['id'],
            "username": profile.get('username'),
            "level": profile['level'],
            "xp_points": profile['xp_points'],
            "xp_to_next_level": profile['xp_to_next_level'],
            "leveled_up": False
        }
        return response_data
    except Exception as e:
        error_message = str(e)
        if "JSON object requested, multiple (or no) rows returned" in error_message:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"error": f"User profile for user_id '{user_id}' not found."}
            )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": "An unexpected server error occurred."}
        )