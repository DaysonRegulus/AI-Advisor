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
    username: str

class AuthResponse(BaseModel):
    access_token: str
    refresh_token: str

# --- NEW MODEL FOR REFRESH TOKEN REQUEST ---
class RefreshTokenRequest(BaseModel):
    refresh_token: str
    
# --- NEW MODEL FOR FORGOT PASSWORD ---
class ForgotPasswordRequest(BaseModel):
    email: EmailStr

# --- Signup Endpoint (Unchanged) ---
@router.post("/auth/signup", status_code=status.HTTP_201_CREATED)
def sign_up(
    request: SignUpRequest,
    supabase: Client = Depends(get_supabase_client)
):
    try:
        auth_response = supabase.auth.sign_up({
            "email": request.email,
            "password": request.password,
        })
        
        new_user = auth_response.user
        if not new_user:
            raise HTTPException(status_code=500, detail="Failed to create user in authentication system.")

        profile_data = {
            "id": new_user.id,
            "username": request.username,
        }
        profile_res = supabase.table("user_profiles").insert(profile_data).execute()

        if not profile_res.data:
            print(f"CRITICAL: User {new_user.id} was created in Auth but profile creation failed.")
            raise HTTPException(status_code=500, detail="Failed to create user profile after authentication.")
        
        return {"message": f"User {request.username} created successfully. Please log in."}

    except AuthApiError as e:
        if "User already registered" in str(e.message):
             raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="A user with this email address already exists."
            )
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e.message))
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))

# --- Login Endpoint (Unchanged) ---
@router.post("/auth/login", response_model=AuthResponse)
def sign_in(
    request: UserCredentials,
    supabase: Client = Depends(get_supabase_client)
):
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

# --- NEW REFRESH TOKEN ENDPOINT ---
@router.post("/auth/refresh-token", response_model=AuthResponse)
def refresh_access_token(
    request: RefreshTokenRequest,
    supabase: Client = Depends(get_supabase_client)
):
    """
    Refreshes the session using a refresh token.
    """
    try:
        # The Supabase client's refresh_session method handles the validation
        # and exchange of the refresh token for a new session.
        refreshed_session = supabase.auth.refresh_session(request.refresh_token)

        # Supabase's token rotation policy might return a new refresh token.
        # It's crucial to use the one from the response.
        return AuthResponse(
            access_token=refreshed_session.session.access_token,
            refresh_token=refreshed_session.session.refresh_token
        )
    except AuthApiError:
        # This error occurs if the refresh token is expired, invalid, or has been revoked.
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token. Please log in again."
        )
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))
    
# --- NEW FORGOT PASSWORD ENDPOINT ---
@router.post("/auth/forgot-password", status_code=status.HTTP_200_OK)
def forgot_password(
    request: ForgotPasswordRequest,
    supabase: Client = Depends(get_supabase_client)
):
    """
    Initiates the password reset process for a user.
    """
    try:
        # This Supabase function securely handles the process of generating a
        # reset token and sending the email.
        supabase.auth.reset_password_for_email(email=request.email)

        # SECURITY BEST PRACTICE: Always return a generic success message.
        # This prevents "user enumeration", where an attacker could use this
        # endpoint to figure out which emails are registered with your service.
        return {"message": "If an account with that email exists, a password reset link has been sent."}

    except Exception as e:
        # Even if an error occurs, we still return a generic message to the client
        # but we should log the error on the server for debugging.
        print(f"An error occurred during password reset attempt: {e}")
        # This ensures the client-side experience is always the same.
        return {"message": "If an account with that email exists, a password reset link has been sent."}