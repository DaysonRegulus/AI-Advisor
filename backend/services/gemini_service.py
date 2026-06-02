# services/gemini_service.py

import os
import hashlib
from dotenv import load_dotenv
load_dotenv()
from groq import Groq
from core.config import settings
from datetime import datetime

DEBUG_LOG_DIR = "debug_logs"
if not os.path.exists(DEBUG_LOG_DIR):
    os.makedirs(DEBUG_LOG_DIR)

# Initialize the Groq client
GROQ_KEY = os.getenv("GROQ_API_KEY")
groq_client = None

if not GROQ_KEY:
    print("WARNING: GROQ_API_KEY not found in environment variables.")
else:
    try:
        groq_client = Groq(api_key=GROQ_KEY)
        print("Groq Client initialized successfully.")
    except Exception as e:
        print(f"Failed to initialize Groq Client: {e}")


# --- Core Function using Groq ---
def get_ai_response(persona_prompt: str, user_message: str, chat_history: list = None, user_id_for_debug: str = None, agent_name_for_debug: str = None) -> str:
    """
    Generates a response using Groq (Llama-3.1-8b-instant) with high daily limits.
    """
    if not groq_client:
        print("ERROR: Groq client is not initialized.")
        return "Error: The AI service is not configured on the server."
    
    print(f"\n--- Calling Groq API (Llama-3.1-8b) ---")
    print(f"Agent: {agent_name_for_debug or 'Unknown'}")
    print(f"User Message: {user_message}")
    
    # Save debug prompts locally if enabled
    if os.getenv("DEBUG_MODE") == "True" and user_id_for_debug and agent_name_for_debug:
        try:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            sanitized_user_id = hashlib.sha256(user_id_for_debug.encode()).hexdigest()[:12]
            filename = f"{DEBUG_LOG_DIR}/prompt_{timestamp}_{sanitized_user_id}_{agent_name_for_debug}.txt"
            with open(filename, 'w', encoding='utf-8') as f:
                f.write("--- PERSONA PROMPT ---\n")
                f.write(persona_prompt + "\n\n")
                f.write("--- CHAT HISTORY ---\n")
                for turn in (chat_history or []):
                    f.write(f"[{turn['role'].upper()}]\n{turn['parts'][0]}\n\n")
                f.write("--- LATEST USER MESSAGE ---\n")
                f.write(user_message + "\n")
        except Exception as e:
            print(f"DEBUGGING ERROR: Could not write debug log file. Error: {e}")

    try:
        # Format history from Gemini style into standard ChatML format (system, user, assistant)
        messages = [
            {"role": "system", "content": persona_prompt}
        ]

        # Convert historical conversation turns
        if chat_history:
            for turn in chat_history:
                role = "assistant" if turn['role'] == "model" else "user"
                messages.append({
                    "role": role,
                    "content": turn['parts'][0]
                })

        # Append current message
        messages.append({"role": "user", "content": user_message})

        # Generate response using Llama-3.1-8b-instant (extremely fast and fully free)
        completion = groq_client.chat.completions.create(
            model="llama-3.1-8b-instant",
            messages=messages,
            temperature=0.7,
            max_tokens=1024,
        )

        response_text = completion.choices[0].message.content
        print(f"Groq Response: {response_text[:100]}...")
        return response_text

    except Exception as e:
        print(f"ERROR: An error occurred while generating Groq response: {e}")
        return f"I'm sorry, an error occurred while trying to connect to the AI service: {e}"