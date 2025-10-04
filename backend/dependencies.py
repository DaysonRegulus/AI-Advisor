# dependencies.py

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from supabase import create_client, Client
from gotrue.errors import AuthApiError

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

# --- Dependency Function for Supabase Client ---
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

# --- Security Dependency ---
# This is a standard way FastAPI handles "Bearer" tokens in the Authorization header.
# The `tokenUrl` doesn't have to be a real endpoint for our use case, it's just required by the spec.
# We define our scheme using HTTPBearer(). This is a more direct
# way to tell FastAPI we just expect a "Bearer <token>" header.
bearer_scheme = HTTPBearer()

def get_current_user(
    # We now depend on our new bearer_scheme.
    # The `token` variable will now be of type HTTPAuthorizationCredentials.
    token: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    supabase: Client = Depends(get_supabase_client)
):
    """
    This dependency extracts a JWT from the Authorization header,
    validates it with Supabase, and returns the user object.
    """
    try:
        # The actual token string is now in the `credentials` attribute.
        user = supabase.auth.get_user(token.credentials)
        return user
    except AuthApiError as e:
        print(f"Auth Error: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except Exception as e:
        print(f"An unexpected error occurred during authentication: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="An unexpected server error occurred during authentication."
        )