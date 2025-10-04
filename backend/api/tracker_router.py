# api/tracker_router.py

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from supabase import Client
from datetime import datetime, timedelta
from typing import Optional, Dict, List

from dependencies import get_supabase_client, get_current_user

router = APIRouter()

# --- Pydantic Models ---
class LogWeightRequest(BaseModel):
    # user_id is REMOVED
    weight_kg: float = Field(..., gt=0)

class LogWaterRequest(BaseModel):
    # user_id is REMOVED
    amount_ml: int = Field(..., gt=0)

class LogFoodRequest(BaseModel):
    # user_id is REMOVED
    food_name: str
    meal_type: str 
    serving_size: Optional[str] = None
    calories: float
    macros: Optional[Dict[str, float]] = None
    micros: Optional[Dict[str, float]] = None

class UserGoals(BaseModel):
    # user_id will be added from the token
    daily_water_goal_ml: Optional[int] = None
    daily_calorie_goal: Optional[int] = None
    weight_goal_kg: Optional[float] = None
    weight_goal_type: Optional[str] = None
    
# ... (Response models remain the same)
class WeightLogResponse(BaseModel):
    id: str
    user_id: str
    weight_kg: float
    created_at: datetime

class WaterLogResponse(BaseModel):
    id: str
    user_id: str
    amount_ml: int
    created_at: datetime
    
class DashboardData(BaseModel):
    todays_water_intake: int
    todays_calorie_intake: float
    latest_weight_log: Optional[WeightLogResponse] = None

class FoodLogResponse(BaseModel):
    id: str
    user_id: str
    food_name: str
    meal_type: str
    serving_size: Optional[str] = None
    calories: float
    macros: Optional[Dict[str, float]] = None
    micros: Optional[Dict[str, float]] = None
    created_at: datetime
    
class NutrientBreakdownResponse(BaseModel):
    total_calories: float
    macros: Dict[str, float]
    micros: Dict[str, float]
    
class ChartDataPoint(BaseModel):
    log_date: datetime
    avg_weight: float


# --- Helper Function for XP (will be refactored later, now uses internal call) ---
async def award_xp(user_id: str, amount: int, event_name: str, supabase: Client):
    # This is a temporary direct call. We will refactor this to a service in Step 13.
    from api.user_router import award_xp as award_xp_logic
    
    class XPRequest:
        def __init__(self, user_id, amount, event_name):
            self.user_id = user_id
            self.amount = amount
            self.event_name = event_name
    
    try:
        # Simulate the request object the award_xp function expects
        request = XPRequest(user_id, amount, event_name)
        # Note: This is not ideal, but avoids the circular dependency / httpx call for now.
        # We are essentially calling the function from the other router directly.
        award_xp_logic(request, supabase)
        print(f"Awarded {amount} XP for event '{event_name}'.")
    except Exception as e:
         print(f"CRITICAL WARNING: Action was logged, but failed to award XP. Error: {e}")


# --- Endpoints ---
@router.get("/trackers/dashboard", response_model=DashboardData)
async def get_dashboard_data(
    current_user=Depends(get_current_user), # <-- PROTECTED
    supabase: Client = Depends(get_supabase_client)
):
    user_id = current_user.user.id
    try:
        res = supabase.rpc("get_dashboard_data", {"user_uuid": user_id}).execute()
        return res.data
    except Exception as e:
        print(f"Error fetching dashboard data: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch dashboard data.")

@router.post("/trackers/log-weight", response_model=WeightLogResponse, status_code=status.HTTP_201_CREATED)
async def log_weight(
    request: LogWeightRequest, 
    current_user=Depends(get_current_user), # <-- PROTECTED
    supabase: Client = Depends(get_supabase_client)
):
    user_id = current_user.user.id
    insert_res = supabase.table("weight_logs").insert({
        "user_id": user_id,
        "weight_kg": request.weight_kg
    }).execute()

    if not insert_res.data:
        raise HTTPException(status_code=500, detail="Failed to log weight.")
    
    new_log = insert_res.data[0]

    one_week_ago = (datetime.utcnow() - timedelta(days=7)).isoformat()
    recent_logs = supabase.table("weight_logs").select("id", count="exact") \
        .eq("user_id", user_id) \
        .gte("created_at", one_week_ago) \
        .execute()
    
    if recent_logs.count == 1:
        await award_xp(user_id, 100, "weekly_weight_log", supabase)

    return new_log

@router.post("/trackers/log-water", status_code=status.HTTP_201_CREATED)
async def log_water(
    request: LogWaterRequest, 
    current_user=Depends(get_current_user), # <-- PROTECTED
    supabase: Client = Depends(get_supabase_client)
):
    user_id = current_user.user.id
    insert_res = supabase.table("water_logs").insert({
        "user_id": user_id,
        "amount_ml": request.amount_ml
    }).execute()

    if not insert_res.data:
        raise HTTPException(status_code=500, detail="Failed to log to water_logs.")

    new_water_log = insert_res.data[0]

    supabase.table("food_logs").insert({
        "user_id": user_id,
        "food_name": f"{request.amount_ml} ml Water",
        "meal_type": "Water",
        "calories": 0,
        "macros": {}, "micros": {}
    }).execute()
    
    await award_xp(user_id, 5, "water_log", supabase)

    return new_water_log

@router.post("/trackers/log-food", response_model=FoodLogResponse, status_code=status.HTTP_201_CREATED)
async def log_food(
    request: LogFoodRequest, 
    current_user=Depends(get_current_user), # <-- PROTECTED
    supabase: Client = Depends(get_supabase_client)
):
    user_id = current_user.user.id
    insert_res = supabase.table("food_logs").insert({
        "user_id": user_id,
        "food_name": request.food_name,
        "meal_type": request.meal_type,
        "serving_size": request.serving_size,
        "calories": request.calories,
        "macros": request.macros,
        "micros": request.micros
    }).execute()

    if not insert_res.data:
        raise HTTPException(status_code=500, detail="Failed to save food log.")
    
    new_log = insert_res.data[0]
    
    start_of_day = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0).isoformat()
    meal_logs_today = supabase.table("food_logs").select("id", count="exact") \
        .eq("user_id", user_id) \
        .eq("meal_type", request.meal_type) \
        .gte("created_at", start_of_day) \
        .execute()

    if meal_logs_today.count == 1:
        await award_xp(user_id, 25, f"{request.meal_type.lower()}_log", supabase)

    return new_log

@router.post("/trackers/goals", response_model=UserGoals)
async def set_user_goals(
    goals: UserGoals, 
    current_user=Depends(get_current_user), # <-- PROTECTED
    supabase: Client = Depends(get_supabase_client)
):
    user_id = current_user.user.id
    # We must add the user_id to the data before upserting
    goals_dict = goals.model_dump()
    goals_dict['user_id'] = user_id
    
    res = supabase.table("user_goals").upsert(goals_dict).execute()
    return res.data[0]

@router.get("/trackers/goals", response_model=UserGoals)
async def get_user_goals(
    current_user=Depends(get_current_user), # <-- PROTECTED
    supabase: Client = Depends(get_supabase_client)
):
    user_id = current_user.user.id
    res = supabase.table("user_goals").select("*").eq("user_id", user_id).single().execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="User goals not found.")
    return res.data

# The rest of the GET endpoints follow the same pattern
@router.get("/trackers/water/today")
async def get_todays_water(
    current_user=Depends(get_current_user), # <-- PROTECTED
    supabase: Client = Depends(get_supabase_client)
):
    user_id = current_user.user.id
    start_of_day = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0).isoformat()
    res = supabase.table("water_logs").select("*").eq("user_id", user_id).gte("created_at", start_of_day).execute()
    return res.data

@router.get("/trackers/food/today")
async def get_todays_food(
    current_user=Depends(get_current_user), # <-- PROTECTED
    supabase: Client = Depends(get_supabase_client)
):
    user_id = current_user.user.id
    start_of_day = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0).isoformat()
    res = supabase.table("food_logs").select("*").eq("user_id", user_id).gte("created_at", start_of_day).execute()
    return res.data

@router.get("/trackers/weight/history")
async def get_weight_history(
    current_user=Depends(get_current_user), # <-- PROTECTED
    supabase: Client = Depends(get_supabase_client)
):
    user_id = current_user.user.id
    res = supabase.table("weight_logs").select("*").eq("user_id", user_id).order("created_at", desc=True).limit(100).execute()
    return res.data

@router.get("/trackers/calories/daily-breakdown", response_model=NutrientBreakdownResponse)
async def get_daily_nutrient_breakdown(
    current_user=Depends(get_current_user), # <-- PROTECTED
    supabase: Client = Depends(get_supabase_client)
):
    user_id = current_user.user.id
    try:
        res = supabase.rpc("get_daily_nutrient_breakdown", {"user_uuid": user_id}).execute()
        if not res.data:
            return NutrientBreakdownResponse(total_calories=0, macros={}, micros={})
        return res.data
    except Exception as e:
        print(f"Error fetching nutrient breakdown: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch nutrient breakdown.")
    
@router.get("/trackers/weight/chart-history", response_model=List[ChartDataPoint])
async def get_weight_chart_history(
    current_user=Depends(get_current_user), # <-- PROTECTED
    period_days: int = 7,
    supabase: Client = Depends(get_supabase_client)
):
    user_id = current_user.user.id
    try:
        params = {"user_uuid": user_id, "days_ago": period_days}
        res = supabase.rpc("get_weight_history_for_chart", params).execute()
        return res.data
    except Exception as e:
        print(f"Error fetching weight chart history: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch chart history.")