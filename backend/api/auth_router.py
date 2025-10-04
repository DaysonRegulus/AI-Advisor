# api/auth_router.py

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr
from supabase import Client
from gotrue.errors import AuthApiError

from dependencies import get_supabase_client

router = APIRouter()

# --- Pydantic Models for Auth ---
class UserCredentials(BaseModel):
    email: EmailStr
    password: str

class SignUpRequest(UserCredentials):
    username: str # Adding username to our signup model

class AuthResponse(BaseModel):
    access_token: str
    refresh_token: str

# --- Signup Endpoint ---
@router.post("/auth/signup", status_code=status.HTTP_201_CREATED)
def sign_up(
    request: SignUpRequest,
    supabase: Client = Depends(get_supabase_client)
):
    """
    Handles new user registration.
    1. Creates the user in Supabase Auth.
    2. Creates a corresponding profile in the `user_profiles` table.
    """
    try:
        # 1. Create the user in Supabase Auth
        auth_response = supabase.auth.sign_up({
            "email": request.email,
            "password": request.password,
        })
        
        new_user = auth_response.user
        if not new_user:
            raise HTTPException(status_code=500, detail="Failed to create user in authentication system.")

        # 2. Create the user's profile in our public `user_profiles` table
        # This step is CRITICAL for linking auth data with your app's data.
        profile_data = {
            "id": new_user.id, # The primary key MUST match the auth user's ID
            "username": request.username,
            # Default values for level, xp, etc. will be set by the database.
        }
        profile_res = supabase.table("user_profiles").insert(profile_data).execute()

        if not profile_res.data:
            # This is a critical failure state. We should ideally roll back the auth user creation.
            # For now, we log it and raise an error.
            print(f"CRITICAL: User {new_user.id} was created in Auth but profile creation failed.")
            raise HTTPException(status_code=500, detail="Failed to create user profile after authentication.")
        
        # We don't return the token here; user must log in after signing up.
        return {"message": f"User {request.username} created successfully. Please log in."}

    except AuthApiError as e:
        # Handle specific auth errors, like a user already existing.
        if "User already registered" in str(e):
             raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="A user with this email address already exists."
            )
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


# --- Login Endpoint ---
@router.post("/auth/login", response_model=AuthResponse)
def sign_in(
    request: UserCredentials,
    supabase: Client = Depends(get_supabase_client)
):
    """
    Authenticates a user and returns a new JWT access token.
    """
    try:
        auth_response = supabase.auth.sign_in_with_password({
            "email": request.email,
            "password": request.password,
        })
        
        return AuthResponse(
            access_token=auth_response.session.access_token,
            refresh_token=auth_response.session.refresh_token
        )

    except AuthApiError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password."
        )
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))