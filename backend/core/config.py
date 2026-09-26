# core/config.py

import os
from pydantic_settings import BaseSettings, SettingsConfigDict

_BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_ENV_PATH = os.path.join(_BASE_DIR, ".env")

class Settings(BaseSettings):
    """
    A centralized class for managing application settings.
    It automatically reads environment variables from .env files.
    """
    model_config = SettingsConfigDict(
        env_file=(_ENV_PATH, ".env", "../.env"),
        env_file_encoding='utf-8',
        extra='ignore'
    )

    # --- AI API Keys ---
    GEMINI_API_KEY: str = ""
    GROQ_API_KEY: str = ""

    # --- Supabase ---
    SUPABASE_URL: str
    SUPABASE_SERVICE_KEY: str # This should be the 'service_role' key
    SUPABASE_KEY: str = ""

# Create a single, importable instance of the settings
settings = Settings()

print("Configuration loaded:")
print(f"  - Supabase URL: {settings.SUPABASE_URL[:20]}...")
print(f"  - Supabase Service Key: {'Loaded' if settings.SUPABASE_SERVICE_KEY else 'NOT LOADED'}")
print(f"  - Gemini API Key: {'Loaded' if settings.GEMINI_API_KEY else 'NOT LOADED'}")
print(f"  - Groq API Key: {'Loaded' if settings.GROQ_API_KEY else 'NOT LOADED'}")