# main.py

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from core.connection_manager import manager

# Import our service and personas
from services.gemini_service import get_ai_response
from core.personas import EXPERT_PERSONAS

# Import our new dependency
from dependencies import get_supabase_client

# Import our routers
from api import ai_router, user_router, overseer_router, journal_router, tracker_router

app = FastAPI(
    title="Personal AI Advisor API",
    description="API for the multi-agent personal AI advisor application.",
    version="1.2.0" # Version bump for new feature
)

# This configures CORS to allow our Flutter app to connect.
# In a production environment, you would restrict origins to your specific app's domain.
origins = [
    "*", # Allows all origins for development
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"], # Allows all methods (GET, POST, etc.)
    allow_headers=["*"], # Allows all headers
)

# --- Include API Routers ---
# This is how we connect the endpoint files to the main app.
# We can add tags to group them nicely in the documentation.
app.include_router(ai_router.router, prefix="/api", tags=["AI Agents"])
app.include_router(user_router.router, prefix="/api", tags=["User Profile"])
app.include_router(overseer_router.router, prefix="/api", tags=["Overseer"]) 
app.include_router(journal_router.router, prefix="/api", tags=["Journal"])
app.include_router(tracker_router.router, prefix="/api", tags=["Trackers"])

# --- WEBSOCKET ENDPOINT ---
@app.websocket("/ws/comments/{user_id}")
async def websocket_endpoint(websocket: WebSocket, user_id: str):
    """
    Handles the WebSocket connection lifecycle for a user.
    """
    await manager.connect(user_id, websocket)
    try:
        # This loop keeps the connection alive.
        # It can be used for two-way communication if needed in the future.
        while True:
            # We wait for data from the client. The client won't send anything
            # in this use case, but the 'await' keeps the connection open.
            # If the client disconnects, a WebSocketDisconnect exception is raised.
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(user_id)
    except Exception as e:
        print(f"An error occurred in the WebSocket for user {user_id}: {e}")
        manager.disconnect(user_id)

# --- API Endpoints ---
# --- Root Endpoint ---
@app.get("/", tags=["Status"])
def read_root():
    """A simple root endpoint to confirm the server is running."""
    return {"status": "ok", "message": "Welcome to the Personal AI Advisor API!"}