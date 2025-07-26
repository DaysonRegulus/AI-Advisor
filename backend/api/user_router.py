# api/user_router.py

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from supabase import Client
from typing import Optional

# Our project imports
from dependencies import get_supabase_client

router = APIRouter()

# --- Helper Function for XP Calculation ---
def calculate_next_level_xp(level: int) -> int:
    """
    Calculates the XP required to reach the next level.
    Uses a simple exponential growth formula.
    """
    return int(100 * (level ** 1.5))

# --- Pydantic Models ---
class AwardXpRequest(BaseModel):
    user_id: str
    amount: int = Field(..., gt=0, description="Amount of XP to award. Must be positive.")
    event_name: str # e.g., "journal_completed", "first_fitness_log" for future analytics

class UserProfileResponse(BaseModel):
    user_id: str
    username: Optional[str] = None
    level: int
    xp_points: int
    xp_to_next_level: int
    leveled_up: bool

# --- The Main Endpoint ---
@router.post(
    "/user/award-xp",
    response_model=UserProfileResponse,
    summary="Award Experience Points to a User",
    description="Awards a specified amount of XP to a user and handles level-up logic."
)
def award_xp(
    request: AwardXpRequest,
    supabase: Client = Depends(get_supabase_client)
):
    """
    Handles the logic for awarding XP and leveling up a user.
    1. Fetches the user's current profile.
    2. Calculates the new XP total and checks for level-ups.
    3. Updates the profile in the database with the new values.
    """
    try:
        # 1. --- Fetch current user profile ---
        print(f"Fetching profile for user: {request.user_id}")
        profile_res = supabase.table("user_profiles").select("*").eq("id", request.user_id).single().execute()
        
        # .single() ensures we get exactly one record or it raises an error.
        if not profile_res.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"User profile not found for user_id: {request.user_id}"
            )
        
        profile = profile_res.data
        print(f"Current profile: Level {profile['level']}, XP {profile['xp_points']}/{profile['xp_to_next_level']}")

        # 2. --- Calculate new XP and handle level-ups ---
        leveled_up = False
        new_xp = profile['xp_points'] + request.amount
        current_level = profile['level']
        xp_for_next = profile['xp_to_next_level']

        while new_xp >= xp_for_next:
            leveled_up = True
            current_level += 1
            new_xp -= xp_for_next  # Carry over the remainder XP
            xp_for_next = calculate_next_level_xp(current_level)
            print(f"LEVEL UP! User is now Level {current_level}. Next level at {xp_for_next} XP.")

        # 3. --- Update the profile in the database ---
        print(f"Updating profile: Level {current_level}, XP {new_xp}/{xp_for_next}")
        update_response = supabase.table("user_profiles").update({
            "level": current_level,
            "xp_points": new_xp,
            "xp_to_next_level": xp_for_next,
            "updated_at": "now()"
        }).eq("id", profile['id']).execute()
        
        if not update_response.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to update user profile in the database."
            )

        # 4. --- Return the updated profile ---
        return UserProfileResponse(
            user_id=profile['id'],
            username=profile.get('username'),
            level=current_level,
            xp_points=new_xp,
            xp_to_next_level=xp_for_next,
            leveled_up=leveled_up
        )

    except Exception as e:
        # Catch potential errors from .single() or other database issues
        print(f"ERROR awarding XP: {e}")
        # Re-raise as an HTTPException to provide a clean error response to the client.
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred while awarding XP: {str(e)}"
        )
@router.get(
    "/user/profile/{user_id}",
    response_model=UserProfileResponse, # Reuse our existing response model
    summary="Get User Profile",
    description="Fetches the complete profile for a given user, including level and XP."
)
def get_user_profile(user_id: str, supabase: Client = Depends(get_supabase_client)):
    try:
        profile_res = supabase.table("user_profiles").select("*").eq("id", user_id).single().execute()
        profile = profile_res.data
        
        # We need to add 'leveled_up' to the response, which is not in the DB.
        # We can just set it to false for a GET request.
        response_data = {
        "user_id": profile['id'],  # <-- THE MAIN FIX: Map 'id' to 'user_id'
        "username": profile.get('username'),
        "level": profile['level'],
        "xp_points": profile['xp_points'],
        "xp_to_next_level": profile['xp_to_next_level'],
        "leveled_up": False
        }

        return response_data
    except Exception as e:
        print(f"Error fetching profile for user {user_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User profile for user {user_id} not found."
        )