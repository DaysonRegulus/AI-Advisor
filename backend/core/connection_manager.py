# core/connection_manager.py
from fastapi import WebSocket
from typing import Dict, List

class ConnectionManager:
    def __init__(self):
        # This dictionary will hold active connections.
        # The key is the user_id, and the value is the WebSocket object.
        self.active_connections: Dict[str, WebSocket] = {}

    async def connect(self, user_id: str, websocket: WebSocket):
        """Accepts a new WebSocket connection and stores it."""
        await websocket.accept()
        self.active_connections[user_id] = websocket
        print(f"New WebSocket connection for user_id: {user_id}. Total connections: {len(self.active_connections)}")

    def disconnect(self, user_id: str):
        """Removes a WebSocket connection."""
        if user_id in self.active_connections:
            del self.active_connections[user_id]
            print(f"WebSocket connection closed for user_id: {user_id}. Total connections: {len(self.active_connections)}")

    async def send_personal_message(self, message: str, user_id: str):
        """Sends a JSON message to a specific user's WebSocket."""
        if user_id in self.active_connections:
            websocket = self.active_connections[user_id]
            await websocket.send_json(message)
            print(f"Sent message to user {user_id}: {message}")

# Create a single, global instance of the manager that our app can use.
manager = ConnectionManager()