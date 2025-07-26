# backend/app/api/journal.py

from fastapi import APIRouter
from supabase import create_client
import os
from dotenv import load_dotenv

load_dotenv()
supabase = create_client(os.getenv("SUPABASE_URL"), os.getenv("SUPABASE_KEY"))
router = APIRouter()

@router.get("/journal/latest")
def get_latest_entry():
    response = supabase.table("journal_entries").select("*").order("date", desc=True).limit(1).execute()
    return response.data
