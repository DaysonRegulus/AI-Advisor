# dependencies.py

from fastapi import Depends, HTTPException, status
from supabase import create_client, Client

# Import our centralized settings
from core.config import settings

# --- Supabase Client Initialization ---
try:
    supabase_client: Client = create_client(
        supabase_url=settings.SUPABASE_URL,
        supabase_key=settings.SUPABASE_SERVICE_KEY
    )
    print("Supabase client created successfully using Service Role.")
except Exception as e:
    print(f"FATAL ERROR: Could not create Supabase client: {e}")
    supabase_client = None

# --- Dependency Function ---
def get_supabase_client() -> Client:
    """
    A FastAPI dependency that provides a Supabase client instance.
    If the client failed to initialize, this will raise an HTTP exception,
    preventing the endpoint from running with a broken database connection.
    """
    if supabase_client is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database connection is not available."
        )
    return supabase_client