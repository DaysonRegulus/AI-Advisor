# api/tracker_router.py

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from supabase import Client
from datetime import datetime, timedelta
from typing import Optional, Dict
import httpx

from dependencies import get_supabase_client

router = APIRouter()

# --- Pydantic Models ---

class LogWeightRequest(BaseModel):
    user_id: str
    weight_kg: float = Field(..., gt=0)

class LogWaterRequest(BaseModel):
    user_id: str
    amount_ml: int = Field(..., gt=0)

class LogFoodRequest(BaseModel):
    user_id: str
    food_name: str
    meal_type: str # Breakfast, Lunch, Dinner, Snacks
    serving_size: Optional[str] = None
    calories: float
    macros: Optional[Dict[str, float]] = None
    micros: Optional[Dict[str, float]] = None
    
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

class UserGoals(BaseModel):
    user_id: str
    daily_water_goal_ml: Optional[int] = None
    daily_calorie_goal: Optional[int] = None
    weight_goal_kg: Optional[float] = None
    weight_goal_type: Optional[str] = None
    
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

# --- Helper Function for XP ---
async def award_xp(user_id: str, amount: int, event_name: str):
    try:
        async with httpx.AsyncClient() as client:
            xp_award_url = "http://127.0.0.1:8000/api/user/award-xp"
            xp_payload = {"user_id": user_id, "amount": amount, "event_name": event_name}
            response = await client.post(xp_award_url, json=xp_payload)
            response.raise_for_status()
            print(f"Awarded {amount} XP for event '{event_name}'.")
    except httpx.HTTPStatusError as e:
        print(f"CRITICAL WARNING: Action was logged, but failed to award XP. Status: {e.response.status_code}")

# --- Endpoints ---
@router.get("/trackers/dashboard/{user_id}", response_model=DashboardData)
async def get_dashboard_data(user_id: str, supabase: Client = Depends(get_supabase_client)):
    try:
        res = supabase.rpc("get_dashboard_data", {"user_uuid": user_id}).execute()
        return res.data
    except Exception as e:
        print(f"Error fetching dashboard data: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch dashboard data.")

@router.post("/trackers/log-weight", response_model=WeightLogResponse, status_code=status.HTTP_201_CREATED)
async def log_weight(request: LogWeightRequest, supabase: Client = Depends(get_supabase_client)):
    # 1. Log the new weight and immediately get the created object back
    insert_res = supabase.table("weight_logs").insert({
        "user_id": request.user_id,
        "weight_kg": request.weight_kg
    }).execute()

    if not insert_res.data:
        raise HTTPException(status_code=500, detail="Failed to log weight.")
    
    new_log = insert_res.data[0]

    # 2. Check if user should be awarded XP (logged once a week)
    one_week_ago = (datetime.utcnow() - timedelta(days=7)).isoformat()
    recent_logs = supabase.table("weight_logs").select("id", count="exact") \
        .eq("user_id", request.user_id) \
        .gte("created_at", one_week_ago) \
        .execute()
    
    # If this is the only log in the past 7 days, award XP
    if recent_logs.count == 1:
        await award_xp(request.user_id, 100, "weekly_weight_log")

    # 3. Return the newly created log object
    return new_log

@router.post("/trackers/log-water", status_code=status.HTTP_201_CREATED)
async def log_water(request: LogWaterRequest, supabase: Client = Depends(get_supabase_client)):
    # Dual-action: log to water_logs for aggregation and food_logs for timeline
    # 1. Log to water_logs
    insert_res = supabase.table("water_logs").insert({
        "user_id": request.user_id,
        "amount_ml": request.amount_ml
    }).execute()

    if not insert_res.data:
        raise HTTPException(status_code=500, detail="Failed to log to water_logs.")

    new_water_log = insert_res.data[0]

    # 2. Log to food_logs for timeline view
    supabase.table("food_logs").insert({
        "user_id": request.user_id,
        "food_name": f"{request.amount_ml} ml Water",
        "meal_type": "Water",
        "calories": 0,
        "macros": {}, "micros": {}
    }).execute()
    
    # 3. Award XP for every log
    await award_xp(request.user_id, 5, "water_log")

    # 4. Return the primary created object
    return new_water_log

@router.post("/trackers/log-food", response_model=FoodLogResponse, status_code=status.HTTP_201_CREATED)
async def log_food(request: LogFoodRequest, supabase: Client = Depends(get_supabase_client)):
    # 1. Insert the new food log
    insert_res = supabase.table("food_logs").insert({
        "user_id": request.user_id,
        "food_name": request.food_name,
        "meal_type": request.meal_type,
        "serving_size": request.serving_size,
        "calories": request.calories,
        "macros": request.macros,
        "micros": request.micros # Pydantic ensures this is a dict or None
    }).execute()

    if not insert_res.data:
        raise HTTPException(status_code=500, detail="Failed to save food log.")
    
    new_log = insert_res.data[0]
    
    # Check if this is the first entry for this meal_type today to award XP
    start_of_day = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0).isoformat()
    meal_logs_today = supabase.table("food_logs").select("id", count="exact") \
        .eq("user_id", request.user_id) \
        .eq("meal_type", request.meal_type) \
        .gte("created_at", start_of_day) \
        .execute()

    if meal_logs_today.count == 1:
        await award_xp(request.user_id, 25, f"{request.meal_type.lower()}_log")

    return new_log

@router.post("/trackers/goals", response_model=UserGoals)
async def set_user_goals(goals: UserGoals, supabase: Client = Depends(get_supabase_client)):
    # Use upsert to create or update the user's goals
    res = supabase.table("user_goals").upsert(goals.model_dump()).execute()
    return res.data[0]

@router.get("/trackers/goals/{user_id}", response_model=UserGoals)
async def get_user_goals(user_id: str, supabase: Client = Depends(get_supabase_client)):
    res = supabase.table("user_goals").select("*").eq("user_id", user_id).single().execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="User goals not found.")
    return res.data

@router.get("/trackers/water/today/{user_id}")
async def get_todays_water(user_id: str, supabase: Client = Depends(get_supabase_client)):
    start_of_day = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0).isoformat()
    res = supabase.table("water_logs").select("*").eq("user_id", user_id).gte("created_at", start_of_day).execute()
    return res.data

@router.get("/trackers/food/today/{user_id}")
async def get_todays_food(user_id: str, supabase: Client = Depends(get_supabase_client)):
    start_of_day = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0).isoformat()
    res = supabase.table("food_logs").select("*").eq("user_id", user_id).gte("created_at", start_of_day).execute()
    return res.data

@router.get("/trackers/weight/history/{user_id}")
async def get_weight_history(user_id: str, supabase: Client = Depends(get_supabase_client)):
    res = supabase.table("weight_logs").select("*").eq("user_id", user_id).order("created_at", desc=True).limit(100).execute()
    return res.data