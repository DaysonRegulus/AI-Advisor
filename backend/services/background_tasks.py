# services/background_tasks.py

from supabase import Client
import tiktoken
from .gemini_service import get_ai_response
from .memory_service import get_active_window_log, TOKEN_THRESHOLD_FOR_SUMMARIZATION, ROW_COUNT_THRESHOLD_FOR_SUMMARIZATION
from core.prompts import CUMULATIVE_SUMMARY_PROMPT
from core.personas import EXPERT_PERSONAS
from datetime import datetime

# --- Tokenizer Setup ---
# We initialize the tokenizer once and reuse it for efficiency.
# "cl100k_base" is the tokenizer used by modern GPT and Gemini models.
try:
    tokenizer = tiktoken.get_encoding("cl100k_base")
    print("Tokenizer 'cl100k_base' loaded successfully.")
except Exception as e:
    print(f"FATAL ERROR: Could not initialize tokenizer: {e}")
    tokenizer = None

# --- Lightweight Task: Asynchronous Token Counting ---

def update_token_count_task(user_id: str, agent_name: str, new_interaction: dict, supabase: Client):
    """
    A background task to calculate tokens for a new interaction and update the DB.
    
    Args:
        user_id (str): The user's ID.
        agent_name (str): The agent's name.
        new_interaction (dict): A dictionary containing 'user_message' and 'ai_response'.
        supabase (Client): The Supabase client instance.
    """
    if not tokenizer:
        print("TOKENIZER ERROR: Cannot update token count because tokenizer is not available.")
        return

    print(f"BACKGROUND TASK: Starting token count update for user '{user_id}', agent '{agent_name}'.")

    try:
        # 1. Calculate tokens for the new interaction
        user_tokens = len(tokenizer.encode(new_interaction['user_message']))
        ai_tokens = len(tokenizer.encode(new_interaction['ai_response']))
        tokens_to_add = user_tokens + ai_tokens

        print(f"New interaction tokens: User={user_tokens}, AI={ai_tokens}, Total={tokens_to_add}")

        # 2. Fetch the current token count from the database
        # We use .select().single() to get one specific record.
        res = supabase.table("memory_stats").select("active_token_count") \
            .eq("user_id", user_id) \
            .eq("agent_name", agent_name) \
            .limit(1).execute()
        
        current_tokens = 0
        # res.data will be None if no record exists yet
        if res.data:
            current_tokens = res.data[0].get('active_token_count', 0)

        new_total_tokens = current_tokens + tokens_to_add

        # 3. Upsert the new total back into the database
        # 'upsert' will create the row if it doesn't exist, or update it if it does.
        supabase.table("memory_stats").upsert({
            "user_id": user_id,
            "agent_name": agent_name,
            "active_token_count": new_total_tokens,
        }).execute()

        print(f"BACKGROUND TASK: Successfully updated token count for agent '{agent_name}' to {new_total_tokens}.")

    except Exception as e:
        # This is a non-critical error. We log it but don't crash the app.
        print(f"BACKGROUND TASK ERROR: Failed during token count update. User: '{user_id}', Agent: '{agent_name}'. Error: {e}")
        
# --- Heavyweight Task: Summarization (Placeholder for now) ---
# We will implement the full logic for this later in this step.

# --- Heavyweight Task: Summarization ---

def trigger_summarization_task(user_id: str, agent_name: str, supabase: Client):
    """
    Performs the heavy memory summarization process based on our defined architecture.
    """
    print(f"HEAVY BACKGROUND TASK: Full summarization logic started for user '{user_id}', agent '{agent_name}'.")

    try:
        # 1. Fetch current memory state
        mem_state_res = supabase.table("memory_stats").select("*") \
            .eq("user_id", user_id) \
            .eq("agent_name", agent_name) \
            .single().execute()
        
        if not mem_state_res.data:
            print("SUMMARIZATION ERROR: No memory state found. Aborting.")
            return

        mem_state = mem_state_res.data
        existing_summary = mem_state.get('cumulative_summary', "")
        active_start_time = mem_state.get('summarized_until_timestamp')

        # 2. Identify the chunk of the active window to summarize
        # We fetch the full active window log first.
        full_active_log = get_active_window_log(user_id, agent_name, active_start_time, supabase)
        
        if not full_active_log:
            print("SUMMARIZATION SKIPPED: No active log items found to summarize.")
            return
        
        # This is our "Grace Window" data + a bit more, based on row count as a proxy.
        # Let's say we summarize the oldest 20 items once the total exceeds 100.
        # We can make this more sophisticated later if needed.
        
        # Define a manageable chunk size
        chunk_size_to_summarize = 20 # How many items to process in one go

        # Decide what to summarize. If the log is small, summarize all of it.
        # If it's large, only summarize the oldest chunk.
        if len(full_active_log) <= chunk_size_to_summarize:
            chunk_to_summarize = full_active_log
            remaining_active_log = [] # Nothing remains in the active window
            print(f"Active log is small ({len(full_active_log)} items). Summarizing all of it.")
        else:
            chunk_to_summarize = full_active_log[:chunk_size_to_summarize]
            remaining_active_log = full_active_log[chunk_size_to_summarize:]
            print(f"Active log is large. Summarizing the oldest {chunk_size_to_summarize} items.")

        # 3. Format the chunk into a single string for the prompt
        new_logs_text = ""
        for item in chunk_to_summarize:
            if item['type'] == 'interaction':
                new_logs_text += f"User: {item['data']['user']}\n{agent_name}: {item['data']['model']}\n\n"
            elif item['type'] == 'journal':
                new_logs_text += f"[Journal Entry at {item['timestamp']}]: {item['data']['user']}\n\n"
            elif item['type'] == 'comment_memory':
                 new_logs_text += f"[User Journal]: {item['data']['user']}\n[{agent_name} Comment]: {item['data']['model']}\n\n"
        
        # 4. Create the full prompt and call Gemini to get the new summary
        # We use a generic persona for this system-level task.
        summarization_prompt = CUMULATIVE_SUMMARY_PROMPT.format(
            existing_summary=existing_summary,
            new_logs=new_logs_text
        )
        
        print(f"Calling Gemini to generate new cumulative summary for {agent_name}...")
        new_cumulative_summary = get_ai_response(
            persona_prompt="You are a helpful AI assistant tasked with summarizing text.",
            user_message=summarization_prompt
        )

        # 5. Recalculate token count for the remaining active log
        new_active_token_count = 0
        if tokenizer:
            for item in remaining_active_log:
                 if item['type'] == 'interaction':
                    new_active_token_count += len(tokenizer.encode(item['data']['user']))
                    new_active_token_count += len(tokenizer.encode(item['data']['model']))
                 # Add other types if needed, or keep it simple for now.
        else:
            print("SUMMARIZATION WARNING: Tokenizer not found, cannot accurately recalculate token count.")

        # 6. Update the database with the new state
        new_summarized_until_timestamp = chunk_to_summarize[-1]['timestamp'].isoformat()

        supabase.table("memory_stats").update({
            "cumulative_summary": new_cumulative_summary,
            "summarized_until_timestamp": new_summarized_until_timestamp,
            "active_token_count": new_active_token_count,
            "last_updated": "now()"
        }).eq("user_id", user_id).eq("agent_name", agent_name).execute()

        print(f"HEAVY BACKGROUND TASK: Summarization successful for {agent_name}. New token count: {new_active_token_count}")

    except Exception as e:
        print(f"HEAVY BACKGROUND TASK ERROR: An error occurred during summarization. Error: {e}")