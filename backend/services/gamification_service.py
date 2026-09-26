# services/gamification_service.py

from supabase import Client
from typing import Dict, Any

def calculate_next_level_xp(level: int) -> int:
    """
    Calculates the XP required to reach the next level using a scaling power curve.
    Formula: 100 * (level ^ 1.5)
    """
    return int(100 * (level ** 1.5))


def award_xp_to_user(
    user_id: str,
    amount: int,
    event_name: str,
    supabase: Client
) -> Dict[str, Any]:
    """
    Awards experience points (XP) to a user, handles level-ups,
    and updates the user's profile in the database.
    
    Args:
        user_id: The UUID of the user.
        amount: Number of XP points to award.
        event_name: Description of the event triggering the XP (for logging/analytics).
        supabase: Active Supabase client instance.
        
    Returns:
        Dict containing user_id, username, level, xp_points, xp_to_next_level, and leveled_up flag.
        
    Raises:
        ValueError: If user profile is not found.
        RuntimeError: If updating the profile in Supabase fails.
    """
    profile_res = supabase.table("user_profiles").select("*").eq("id", user_id).single().execute()
    
    if not profile_res.data:
        raise ValueError(f"User profile not found for user_id: {user_id}")
    
    profile = profile_res.data
    leveled_up = False
    new_xp = profile.get('xp_points', 0) + amount
    current_level = profile.get('level', 1)
    xp_for_next = profile.get('xp_to_next_level', 100)

    # Process one or more level-ups if enough XP was gained
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
        raise RuntimeError("Failed to update user profile in the database.")
    
    print(f"Awarded {amount} XP to user '{user_id}' for event '{event_name}'. Level: {current_level}, Total XP: {new_xp}")

    return {
        "user_id": profile['id'],
        "username": profile.get('username'),
        "level": current_level,
        "xp_points": new_xp,
        "xp_to_next_level": xp_for_next,
        "leveled_up": leveled_up
    }
