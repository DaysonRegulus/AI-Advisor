# main.py

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Depends
from fastapi.middleware.cors import CORSMiddleware
from core.connection_manager import manager
from supabase import Client
from gotrue.errors import AuthApiError

# Import our service and personas
from services.gemini_service import get_ai_response
from core.personas import EXPERT_PERSONAS

# Import our new dependency
from dependencies import get_supabase_client

# Import our routers
from api import ai_router, user_router, overseer_router, journal_router, tracker_router, auth_router

app = FastAPI(
    title="Personal AI Advisor API",
    description="API for the multi-agent personal AI advisor application.",
    version="1.3.0" # Version bump for new feature
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
app.include_router(auth_router.router, prefix="/api", tags=["Authentication"])

# --- WEBSOCKET ENDPOINT ---
@app.websocket("/ws/comments") # <-- Path no longer contains {user_id}
async def websocket_endpoint(
    websocket: WebSocket,
    token: str, # <-- FastAPI automatically gets this from a '?token=...' query parameter
    supabase: Client = Depends(get_supabase_client)
):
    """
    Handles an authenticated WebSocket connection.
    It validates the user's JWT token before establishing the connection.
    """
    user_id = None
    try:
        # 1. AUTHENTICATE: The very first step is to validate the token.
        user_response = supabase.auth.get_user(token)
        user_id = user_response.user.id
        print(f"WebSocket: Token validated for user_id: {user_id}")

        # 2. CONNECT: If authentication succeeds, connect the user.
        await manager.connect(user_id, websocket)

        # 3. LISTEN: Keep the connection alive to receive/send messages.
        while True:
            # This is a one-way street for us (server-to-client).
            # We just wait here. If the client disconnects, it will raise an exception.
            await websocket.receive_text()

    except AuthApiError:
        # This block runs if supabase.auth.get_user(token) fails.
        print(f"WebSocket: Invalid token received. Closing connection.")
        # Close the connection with a "Policy Violation" code.
        await websocket.close(code=1008)

    except WebSocketDisconnect:
        # This block runs if the client disconnects gracefully.
        if user_id:
            manager.disconnect(user_id)
        print(f"WebSocket: Client disconnected.")

    except Exception as e:
        # Catch any other unexpected errors.
        print(f"An error occurred in the WebSocket for user {user_id}: {e}")
        if user_id:
            manager.disconnect(user_id)
        # We can also attempt to close the websocket here if it's still open
        if not websocket.client_state.DISCONNECTED:
            await websocket.close(code=1011) # Internal Error

# --- API Endpoints ---
# --- Root Endpoint ---
@app.get("/", tags=["Status"])
def read_root():
    """A simple root endpoint to confirm the server is running."""
    return {"status": "ok", "message": "Welcome to the Personal AI Advisor API!"}