# core/config.py

from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    """
    A centralized class for managing application settings.
    It automatically reads environment variables from a .env file.
    """
    # Tell pydantic to look for a .env file
    model_config = SettingsConfigDict(env_file="./.env", env_file_encoding='utf-8', extra='ignore')

    # --- Gemini API ---
    GEMINI_API_KEY: str

    # --- Supabase ---
    SUPABASE_URL: str
    SUPABASE_SERVICE_KEY: str # This should be the 'service_role' key

# Create a single, importable instance of the settings
settings = Settings()

print("Configuration loaded:")
print(f"  - Supabase URL: {settings.SUPABASE_URL[:20]}...")
print(f"  - Supabase Service Key: {'Loaded' if settings.SUPABASE_SERVICE_KEY else 'NOT LOADED'}")
print(f"  - Gemini API Key: {'Loaded' if settings.GEMINI_API_KEY else 'NOT LOADED'}")