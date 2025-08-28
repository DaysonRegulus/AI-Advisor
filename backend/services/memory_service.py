# services/memory_service.py

from supabase import Client
from dateutil import parser
from datetime import datetime, timedelta
from typing import List, Dict, Any

# Define our summarization thresholds
# We'll use these later when triggering the background task
TOKEN_THRESHOLD_FOR_SUMMARIZATION = 800000  # Set high as per our design
# A proxy for token count to avoid tokenizing full history on every request
# A good starting point, can be tuned.
ROW_COUNT_THRESHOLD_FOR_SUMMARIZATION = 100 

def construct_memory_stream(user_id: str, agent_name: str, supabase: Client) -> List[Dict[str, Any]]:
    """
    Constructs a memory stream using the "Cumulative Summary + Active Window" model.
    """
    print(f"Constructing SCALABLE memory for agent '{agent_name}', user '{user_id}'...")
    gemini_history = []

    try:
        # 1. Fetch the memory state for this user/agent pair
        memory_state_res = supabase.table("memory_stats").select("cumulative_summary, summarized_until_timestamp") \
            .eq("user_id", user_id) \
            .eq("agent_name", agent_name) \
            .limit(1) \
            .execute()
        
        cumulative_summary = ""
        # The timestamp from which to fetch "active" raw history
        active_window_start_time = None

        # res.data will be a list. Check if it's not empty.
        if memory_state_res.data:
            # If it's not empty, get the first (and only) item
            mem_state = memory_state_res.data[0]
            cumulative_summary = mem_state.get('cumulative_summary', "")
            active_window_start_time = mem_state.get('summarized_until_timestamp')
        
        # 2. Add the cumulative summary as the first item in the history (if it exists)
        if cumulative_summary:
            summary_prompt = f"[This is a summary of your distant past conversations and the user's journal entries. Use it for long-term context.]\n{cumulative_summary}"
            gemini_history.append({'role': 'user', 'parts': [summary_prompt]})
            gemini_history.append({'role': 'model', 'parts': ["Understood. I will use this long-term context for our conversation."]})
            print("Added cumulative summary to memory stream.")
            
        # --- Fetch Current Day's Tracker Data ---
        tracker_context = get_todays_tracker_context(user_id, agent_name, supabase)
        if tracker_context:
            # Prepend the tracker context to the memory stream
            gemini_history.append({'role': 'user', 'parts': [f"[Today's Tracker Data]:\n{tracker_context}"]})
            gemini_history.append({'role': 'model', 'parts': ["Understood. I will use this real-time health data in my analysis."]})
            print(f"Added tracker context for {agent_name}.")


        # 3. Fetch the "Active Window" of raw logs
        # This uses the same logic as our old memory service, but now it's filtered by time.
        active_log = get_active_window_log(user_id, agent_name, active_window_start_time, supabase)
        
        # 4. Format the active log for Gemini
        for item in active_log:
            if item['type'] == 'interaction':
                ts = item['timestamp'].strftime('%Y-%m-%d %H:%M')
                gemini_history.append({'role': 'user', 'parts': [f"[User message at {ts}]:\n{item['data']['user']}"]})
                gemini_history.append({'role': 'model', 'parts': [f"[Agent reply at {ts}]:\n{item['data']['model']}"]})
            elif item['type'] == 'journal':
                journal_prompt = f"[User's personal journal entry, written at {item['timestamp'].strftime('%Y-%m-%d %H:%M')}]:\n{item['data']['user']}"
                gemini_history.append({'role': 'user', 'parts': [journal_prompt]})
                gemini_history.append({'role': 'model', 'parts': ["Understood. I have taken note of this journal entry."]})
            elif item['type'] == 'comment_memory':
                ts = item['timestamp'].strftime('%Y-%m-%d %H:%M')
                gemini_history.append({'role': 'user', 'parts': [f"[Related journal context at {ts}]:\n{item['data']['user']}"]})
                gemini_history.append({'role': 'model', 'parts': [f"[AI comment at {ts}]:\n{item['data']['model']}"]})
        
        # --- Integrated Bug Fix: Add Date Context for Overseer ---
        if agent_name == "master_overseer":
            print("Overseer detected: Fetching its own past daily summaries...")
            today_date = datetime.now().strftime("%Y-%m-%d")
            date_prompt = f"[CONTEXT: Today's date is {today_date}. Only include events that occurred today. Do not attribute previous days' logs to today.]"
            thirty_days_ago_str = (datetime.now() - timedelta(days=30)).isoformat()
            past_summaries_res = supabase.table("daily_summaries") \
                .select("summary_text, date") \
                .eq("user_id", user_id) \
                .gte("created_at", thirty_days_ago_str) \
                .order("date", desc=True) \
                .execute()
            # Insert it right after the persona, at the start of the conversation
            gemini_history.insert(0, {'role': 'user', 'parts': [date_prompt]})
            gemini_history.insert(1, {'role': 'model', 'parts': ["Acknowledged. I will analyze the logs with today's date in mind."]})
            print("Added today's date context for Master Overseer.")
            
            if past_summaries_res.data:
                past_summaries_text = "\n\n".join([f"[Your summary from {s['date']}]:\n{s['summary_text']}" for s in past_summaries_res.data])
                summary_context_prompt = f"[CONTEXT: Here are your own previous daily summaries from the last 30 days for continuity.]\n{past_summaries_text}"
                # Insert this context right after the date context
                gemini_history.insert(2, {'role': 'user', 'parts': [summary_context_prompt]})
                gemini_history.insert(3, {'role': 'model', 'parts': ["Understood. I will use my previous summaries for context."]})
                print("Added past daily summaries to Overseer memory.")

        print(f"Constructed final memory stream with {len(gemini_history)} turns.")
        return gemini_history

    except Exception as e:
        print(f"ERROR: Failed during scalable memory construction. Error: {e}")
        # In case of error (e.g., .single() fails), fall back to the old method to ensure app doesn't break
        # This is a safety net. The old function is not here anymore, so we just return empty list
        return []

def get_active_window_log(user_id: str, agent_name: str, start_time: str, supabase: Client) -> List[Dict]:
    """
    Fetches and merges all relevant logs since the last summarization.
    This function implements the "Personalized Worldview" models.
    """
    
    # Base queries for interactions and journals
    interaction_query = supabase.table("ai_interactions").select("user_message, ai_response, created_at") \
        .eq("user_id", user_id)
    journal_query = supabase.table("journal_entries").select("id, content, created_at") \
        .eq("user_id", user_id)
    comment_query = supabase.table("journal_comments").select("comment_text, created_at, entry:journal_entries!inner(content)") \
        .eq("entry.user_id", user_id)

    # Apply time filter if a start_time exists
    if start_time:
        interaction_query = interaction_query.gte("created_at", start_time)
        journal_query = journal_query.gte("created_at", start_time)
        comment_query = comment_query.gte("created_at", start_time)

    # --- Apply "Worldview" logic ---
    if agent_name == "master_overseer":
        # Overseer gets all interactions, but only for the last 30 days for performance
        thirty_days_ago = (datetime.now() - timedelta(days=30)).isoformat()
        interaction_query = interaction_query.gte("created_at", thirty_days_ago)
        journal_query = journal_query.gte("created_at", thirty_days_ago)
        comment_query = comment_query.gte("created_at", thirty_days_ago)
    else:
        # Regular agents only get their own interactions and comments
        interaction_query = interaction_query.eq("agent_name", agent_name)
        comment_query = comment_query.eq("agent_name", agent_name)

    # Execute all queries
    interactions_res = interaction_query.execute()
    journals_res = journal_query.execute()
    comments_res = comment_query.execute()
    
    # --- Integrated Bug Fix: Add Journal Comments to Overseer Memory ---
    # The 'master_overseer' logic above now correctly fetches all comments, not just its own.
    
    # Combine and sort the results (same logic as before)
    unified_log = []
    # This includes the for loops for interactions_res, journals_res, and comments_res
    # Ensure to use parser.isoparse() for all timestamps.
    if interactions_res.data:
        for item in interactions_res.data:
            unified_log.append({
                "timestamp": parser.isoparse(item['created_at']), "type": "interaction",
                "data": {"user": item['user_message'], "model": item['ai_response']}
            })
    if journals_res.data:
        for item in journals_res.data:
            unified_log.append({
                "timestamp": parser.isoparse(item['created_at']), "type": "journal",
                "data": {"user": item['content']}
            })
    if comments_res.data:
        for item in comments_res.data:
            unified_log.append({
                "timestamp": parser.isoparse(item['created_at']), "type": "comment_memory",
                "data": {"user": f"[User's journal entry]:\n{item['entry']['content']}", "model": item['comment_text']}
            })

    unified_log.sort(key=lambda x: x['timestamp'])
    return unified_log

def get_todays_tracker_context(user_id: str, agent_name: str, supabase: Client) -> str:
    """
    Fetches and formats a string of today's relevant tracker data for a specific agent.
    """
    context_parts = []
    start_of_day = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0).isoformat()

    # Define which trackers are relevant for each agent
    relevance_map = {
        'personal_trainer': ['weight', 'water', 'calories', 'food'],
        'mental_health_professional': [],
        'financial_advisor': [],
        'career_coach': [],
        'communication_coach': [],
        'productivity_coach': ['food'],
        'personal_stylist': ['weight'],
        'master_overseer': ['weight', 'water', 'calories', 'food']
    }
    
    agent_relevance = relevance_map.get(agent_name, [])
    if not agent_relevance:
        return ""

    # Fetch data based on relevance
    if 'weight' in agent_relevance:
        res = supabase.table("weight_logs").select("weight_kg").eq("user_id", user_id).order("created_at", desc=True).limit(1).execute()
        if res.data:
            context_parts.append(f"Latest Weight: {res.data[0]['weight_kg']} kg")

    if 'water' in agent_relevance:
        res = supabase.table("water_logs").select("amount_ml").eq("user_id", user_id).gte("created_at", start_of_day).execute()
        if res.data:
            total_water = sum(item['amount_ml'] for item in res.data)
            context_parts.append(f"Water Intake Today: {total_water} ml")

    if 'calories' in agent_relevance:
        res = supabase.table("food_logs").select("calories").eq("user_id", user_id).gte("created_at", start_of_day).execute()
        if res.data:
            total_calories = sum(item['calories'] for item in res.data if item['calories'] is not None)
            context_parts.append(f"Calories Consumed Today: {total_calories:.0f} kcal")

    # For 'food', we just indicate that the agent has access to it.
    # The full log is already in the main memory stream via `get_active_window_log`.
    if 'food' in agent_relevance:
        context_parts.append("Daily food log is available in the history.")
        
    return " | ".join(context_parts)