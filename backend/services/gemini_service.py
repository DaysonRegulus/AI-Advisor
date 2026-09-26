# services/gemini_service.py
# AI service using Groq with qwen/qwen3.8-27b for high rate limits on free tier

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
GROQ_KEY = settings.GROQ_API_KEY or os.getenv("GROQ_API_KEY")
groq_client = None

if not GROQ_KEY:
    print("WARNING: GROQ_API_KEY not found in environment variables.")
else:
    try:
        groq_client = Groq(api_key=GROQ_KEY)
        print("Groq Client initialized successfully.")
    except Exception as e:
        print(f"Failed to initialize Groq Client: {e}")

# Primary free Groq model
PRIMARY_GROQ_MODEL = "qwen/qwen3.8-27b"
FALLBACK_GROQ_MODEL = "openai/gpt-oss-20b"


def get_ai_response(persona_prompt: str, user_message: str, chat_history: list = None, user_id_for_debug: str = None, agent_name_for_debug: str = None) -> str:
    """
    Generates a response using Groq (qwen/qwen3.8-27b).
    """
    if not groq_client:
        print("ERROR: Groq client is not initialized.")
        return "Error: The AI service is not configured on the server."

    print(f"\n--- Calling Groq API ({PRIMARY_GROQ_MODEL}) ---")
    print(f"Agent: {agent_name_for_debug or 'Unknown'}")
    print(f"User Message: {user_message[:100]}...")

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
                    role_str = turn.get('role', 'user').upper()
                    content_str = turn['parts'][0] if 'parts' in turn else turn.get('content', '')
                    f.write(f"[{role_str}]\n{content_str}\n\n")
                f.write("--- LATEST USER MESSAGE ---\n")
                f.write(user_message + "\n")
        except Exception as e:
            print(f"DEBUGGING ERROR: Could not write debug log file. Error: {e}")

    # Build chat messages format for Groq
    messages = [{"role": "system", "content": persona_prompt}]

    if chat_history:
        for turn in chat_history:
            role = "assistant" if turn.get('role') == "model" else "user"
            part_content = turn['parts'][0] if 'parts' in turn else turn.get('content', '')
            messages.append({"role": role, "content": str(part_content)})

    messages.append({"role": "user", "content": user_message})

    # Try primary Groq model, then fallback
    for model_name in [PRIMARY_GROQ_MODEL, FALLBACK_GROQ_MODEL]:
        try:
            completion = groq_client.chat.completions.create(
                model=model_name,
                messages=messages,
                temperature=0.7,
                max_tokens=1024,
            )
            response_text = completion.choices[0].message.content
            print(f"Groq Response ({model_name}): {response_text[:100]}...")
            return response_text
        except Exception as e:
            print(f"Groq generation error with {model_name}: {e}")

    return "I'm sorry, an error occurred while connecting to the AI service. Please try again."