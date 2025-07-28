# services/memory_service.py

from supabase import Client
from datetime import datetime
from typing import List, Dict, Any

def construct_memory_stream(user_id: str, agent_name: str, supabase: Client) -> List[Dict[str, Any]]:
    """
    Constructs a "Personalized Worldview" memory stream for a specific agent.

    This function fetches:
    1. All journal entries for the user.
    2. All AI interactions for the specific agent.
    
    It then merges and sorts them chronologically to create a unified history.

    Returns:
        A list of dictionaries formatted for the Gemini API.
    """
    print(f"Constructing unified memory for agent '{agent_name}' and user '{user_id}'...")

    try:
        # 1. Fetch AI Interactions for the specific agent
        interactions_res = supabase.table("ai_interactions").select("user_message, ai_response, created_at") \
            .eq("user_id", user_id) \
            .eq("agent_name", agent_name) \
            .execute()
        
        # 2. Fetch ALL Journal Entries for the user
        journals_res = supabase.table("journal_entries").select("content, created_at") \
            .eq("user_id", user_id) \
            .execute()
            
        # 3. Fetch all Journal Comments made by this specific agent
        comments_res = supabase.table("journal_comments").select("comment_text, created_at, entry:journal_entries!inner(content)") \
            .eq("agent_name", agent_name) \
            .eq("entry.user_id", user_id) \
            .execute()

    except Exception as e:
        print(f"ERROR: Database query failed during memory construction: {e}")
        return [] # Return empty memory on DB error

    # 4. Standardize and combine data
    unified_log = []

    if interactions_res.data:
        for item in interactions_res.data:
            # Add both user message and model response as a sequence
            unified_log.append({
                "timestamp": datetime.fromisoformat(item['created_at']),
                "type": "interaction",
                "data": {
                    "user": item['user_message'],
                    "model": item['ai_response']
                }
            })

    if journals_res.data:
        for item in journals_res.data:
            unified_log.append({
                "timestamp": datetime.fromisoformat(item['created_at']),
                "type": "journal",
                "data": {
                    "user": item['content']
                }
            })
            
    # --- NEW: Process Comments ---
    if comments_res.data:
        for item in comments_res.data:
            # This represents the AI's "thought" process: seeing a journal and commenting on it.
            unified_log.append({
                "timestamp": datetime.fromisoformat(item['created_at']),
                "type": "comment_memory",
                "data": {
                    # The original journal entry is the "user" part
                    "user": f"[The user wrote this journal entry, which you commented on]:\n{item['entry']['content']}",
                    # The comment is the "model" part
                    "model": item['comment_text']
                }
            })

    # 5. Sort the combined log chronologically
    unified_log.sort(key=lambda x: x['timestamp'])
    print(f"Unified memory contains {len(unified_log)} items.")

    # 6. Format for Gemini API
    gemini_history = []
    for item in unified_log:
        if item['type'] == 'interaction':
            gemini_history.append({'role': 'user', 'parts': [item['data']['user']]})
            gemini_history.append({'role': 'model', 'parts': [item['data']['model']]})
        elif item['type'] == 'journal':
            # We frame the journal entry as a thought the user had.
            journal_prompt = f"[User's personal journal entry, written at {item['timestamp'].strftime('%Y-%m-%d %H:%M')}]:\n{item['data']['user']}"
            gemini_history.append({'role': 'user', 'parts': [journal_prompt]})
            # We add a model part to acknowledge the entry, making the conversation flow more natural for the AI.
            gemini_history.append({'role': 'model', 'parts': ["Understood. I have taken note of this journal entry."]})
        # --- NEW: Handle the comment memory type ---
        elif item['type'] == 'comment_memory':
            gemini_history.append({'role': 'user', 'parts': [item['data']['user']]})
            gemini_history.append({'role': 'model', 'parts': [item['data']['model']]})

    return gemini_history