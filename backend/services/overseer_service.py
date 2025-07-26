# services/overseer_service.py

from supabase import Client
import datetime
from typing import Optional

# Import our existing Gemini service and personas
from .gemini_service import get_ai_response
from core.personas import EXPERT_PERSONAS

def generate_daily_summary_for_user(user_id: str, supabase: Client) -> Optional[str]:
    """
    The core logic for the Master Overseer.

    1. Fetches all journal entries and AI interactions for a user in the last 24 hours.
    2. Consolidates them into a single, structured prompt.
    3. Sends the prompt to Gemini with the Master Overseer persona.
    4. Returns the generated summary text.

    Args:
        user_id: The UUID of the user.
        supabase: The Supabase client instance.

    Returns:
        The summary text as a string, or None if no data was found to summarize.
    """
    print(f"Starting daily summary generation for user_id: {user_id}")

    # --- 1. Fetch Data from the Last 24 Hours ---
    now = datetime.datetime.utcnow()
    twenty_four_hours_ago = now - datetime.timedelta(days=1)
    
    # Convert to the format Supabase expects (ISO 8601 with timezone)
    time_threshold = twenty_four_hours_ago.isoformat() + "Z"
    print(f"Fetching logs since: {time_threshold}")

    try:
        journal_res = supabase.table("journal_entries").select("content, created_at") \
            .eq("user_id", user_id) \
            .gte("created_at", time_threshold) \
            .order("created_at") \
            .execute()

        interactions_res = supabase.table("ai_interactions").select("agent_name, user_message, ai_response, created_at") \
            .eq("user_id", user_id) \
            .gte("created_at", time_threshold) \
            .order("created_at") \
            .execute()
        
        # --- CONTEXT FETCHING (Happens regardless of today's data) ---
        previous_summary = "No Activity"
        try:
            # Fetch the most recent summary from any previous day for context.
            prev_res = supabase.table("daily_summaries") \
                .select("summary_text") \
                .eq("user_id", user_id) \
                .order("date", desc=True) \
                .limit(1) \
                .maybe_single() \
                .execute()
            if prev_res.data:
                previous_summary = prev_res.data.get("summary_text", "")
                print("Found previous summary to use as context.")
        except Exception as e:
            print(f"Could not fetch previous summary, proceeding without it. Error: {e}")

        # --- "NO DATA" LOGIC ---
        if not journal_res.data and not interactions_res.data:
            print("No recent data found. Generating an encouragement summary.")
            master_persona = EXPERT_PERSONAS["master_overseer"]
            
            # This prompt is framed as an analytical task, which the Overseer will follow.
            # We also provide the previous summary as context.
            encouragement_prompt = f"""
            CONTEXT: The user's summary from the previous day was: '{previous_summary}'

            ANALYSIS TASK: The user has no new logs for today. Based on the previous day's context, if there, generate a new summary block.
            This summary should be a brief, single paragraph. It should acknowledge the lack of new activity and gently encourage the user to engage by either writing a journal entry or chatting with a coach.
            Maintain a supportive but analytical tone.
            """
            
            summary_text = get_ai_response(
                persona_prompt=master_persona,
                user_message=encouragement_prompt
            )
            return summary_text

    except Exception as e:
        print(f"ERROR: Database query failed during summary generation: {e}")
        return None

    # --- 2. Consolidate Data into a Structured Prompt ---
    consolidated_prompt = f"""
    CONTEXT: The user's summary from the previous day was: '{previous_summary}'

    TASK: Please generate a new daily summary based on the following logs for the user. Analyze their activities, moods, progress, and look for cross-domain insights or conflicts. Keep the output to a single, concise paragraph.
    \n\n
    """
    consolidated_prompt += "--- CONSOLIDATED LOGS ---\n\n"
    
    # Add Journal Entries to prompt
    if journal_res.data:
        consolidated_prompt += "=== USER JOURNAL ENTRIES ===\n"
        for entry in journal_res.data:
            consolidated_prompt += f"Timestamp: {entry['created_at']}\nEntry: {entry['content']}\n\n"
    
    # Add AI Interactions to prompt
    if interactions_res.data:
        consolidated_prompt += "=== CONVERSATIONS WITH AI AGENTS ===\n"
        for interaction in interactions_res.data:
            consolidated_prompt += f"Agent: {interaction['agent_name']}\n"
            consolidated_prompt += f"Timestamp: {interaction['created_at']}\n"
            consolidated_prompt += f"User said: {interaction['user_message']}\n"
            consolidated_prompt += f"Agent replied: {interaction['ai_response']}\n---\n\n"
    
    consolidated_prompt += "--- END OF LOGS ---"
    
    # For debugging, print the size of the prompt
    print(f"Generated a consolidated prompt of {len(consolidated_prompt)} characters.")

    # --- 3. Call Gemini Service ---
    master_persona = EXPERT_PERSONAS["master_overseer"]
    
    summary_text = get_ai_response(
        persona_prompt=master_persona,
        user_message=consolidated_prompt
    )

    return summary_text