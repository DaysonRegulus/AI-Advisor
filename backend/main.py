# main.py

from fastapi import FastAPI, Depends, status 

# Import our service and personas
from services.gemini_service import get_ai_response
from core.personas import EXPERT_PERSONAS

# Import our new dependency
from dependencies import get_supabase_client

# Import our routers
from api import ai_router, user_router, overseer_router, journal_router

app = FastAPI(
    title="Personal AI Advisor API",
    description="API for the multi-agent personal AI advisor application.",
    version="1.2.0" # Version bump for new feature
)

# --- Include API Routers ---
# This is how we connect the endpoint files to the main app.
# We can add tags to group them nicely in the documentation.
app.include_router(ai_router.router, prefix="/api", tags=["AI Agents"])
app.include_router(user_router.router, prefix="/api", tags=["User Profile"])
app.include_router(overseer_router.router, prefix="/api", tags=["Overseer"]) 
app.include_router(journal_router.router, prefix="/api", tags=["Journal"])

# --- API Endpoints ---
# --- Root Endpoint ---
@app.get("/", tags=["Status"])
def read_root():
    """A simple root endpoint to confirm the server is running."""
    return {"status": "ok", "message": "Welcome to the Personal AI Advisor API!"}