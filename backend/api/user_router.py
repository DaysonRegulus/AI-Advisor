# api/user_router.py

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from supabase import Client
from typing import Optional

# Our project imports
from dependencies import get_supabase_client, get_current_user
from services.gamification_service import calculate_next_level_xp, award_xp_to_user

router = APIRouter()

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
        result = award_xp_to_user(
            user_id=user_id,
            amount=request.amount,
            event_name=request.event_name,
            supabase=supabase
        )
        return UserProfileResponse(**result)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e)
        )
    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
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