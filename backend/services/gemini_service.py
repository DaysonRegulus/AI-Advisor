# services/gemini_service.py

import os
import google.generativeai as genai
from dotenv import load_dotenv
from datetime import datetime

DEBUG_LOG_DIR = "debug_logs"
if not os.path.exists(DEBUG_LOG_DIR):
    os.makedirs(DEBUG_LOG_DIR)

# --- Configuration ---
# Load environment variables from the .env file in the project root
print("Loading environment variables...")
load_dotenv()
print("Environment variables loaded.")

# Fetch the API key from the environment variables
API_KEY = os.getenv("GEMINI_API_KEY")

# --- Error Handling for Configuration ---
if not API_KEY:
    # This is a critical error. The application cannot run without the API key.
    raise ValueError("FATAL ERROR: GEMINI_API_KEY not found in environment variables. Please check your .env file.")

# Configure the Google AI client library with the API key
try:
    genai.configure(api_key=API_KEY)
    print("Gemini API configured successfully.")
except Exception as e:
    # This could happen if the key is invalid or there's a network issue during setup.
    raise RuntimeError(f"Failed to configure Gemini API: {e}")


# --- Model Selection ---
# For this app, Gemini 2.5 Flash is the perfect choice.
# Reasoning:
# 1. Speed: It's designed for high-speed, responsive chat applications.
# 2. Cost: It's the second most cost-effective model in the 2.5 family for the free tier and beyond.
# 3. Context Window: It has a massive context window, which will be essential for our Master Overseer AI later.
model = genai.GenerativeModel('gemini-2.5-flash')
print("Gemini model 'gemini-2.5-flash' selected.")

# --- Core Function ---
def get_ai_response(persona_prompt: str, user_message: str, chat_history: list = None, user_id_for_debug: str = None, agent_name_for_debug: str = None) -> str:
    """
    Generates a response from a Gemini agent with a specific persona and chat history.

    Args:
        persona_prompt (str): The system prompt defining the AI's role, tone, and rules.
        user_message (str): The user's latest message.
        chat_history (list, optional): A list of previous conversation turns.
                                       Defaults to None. Example:
                                       [{'role': 'user', 'parts': ['Hello']},
                                        {'role': 'model', 'parts': ['Hi there!']}]

    Returns:
        str: The AI's generated text response.
    
    Raises:
        Exception: Propagates exceptions from the API call for upstream handling.
    """
    print(f"\n--- Calling Gemini API with Persona ---")
    print(f"Persona: {persona_prompt[:80]}...") # Print first 80 chars of persona
    print(f"User Message: {user_message}")
    
    if os.getenv("DEBUG_MODE") == "True" and user_id_for_debug and agent_name_for_debug:
        try:
            # Create a unique filename for each request
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"{DEBUG_LOG_DIR}/prompt_{timestamp}_{user_id_for_debug}_{agent_name_for_debug}.txt"
            
            with open(filename, 'w', encoding='utf-8') as f:
                f.write("--- PERSONA PROMPT ---\n")
                f.write(persona_prompt + "\n\n")
                
                f.write("--- CHAT HISTORY ---\n")
                for turn in (chat_history or []):
                    f.write(f"[{turn['role'].upper()}]\n{turn['parts'][0]}\n\n")
                
                f.write("--- LATEST USER MESSAGE ---\n")
                f.write(user_message + "\n")
            
            print(f"DEBUG: Saved full prompt to {filename}")
        except Exception as e:
            print(f"DEBUGGING ERROR: Could not write debug log file. Error: {e}")

    try:
        # The chat history format is specific. The persona acts as the first "system" instruction.
        # We prime the model by telling it we've understood the persona instructions.
        # This makes its subsequent responses more reliable and in-character.
        full_prompt = [
            {'role': 'user', 'parts': [persona_prompt]},
            {'role': 'model', 'parts': ["Understood. I am ready to assist in my role."]}
        ]

        # If chat history is provided, append it to the prompt
        if chat_history:
            full_prompt.extend(chat_history)
        
        # Append the latest user message
        full_prompt.append({'role': 'user', 'parts': [user_message]})
        
        # Generate the content
        response = model.generate_content(full_prompt)
        
        print(f"Gemini Response: {response.text[:100]}...") # Print first 100 chars
        return response.text

    except Exception as e:
        # If the API call fails for any reason (e.g., network error, content filtering),
        # we log the error and return a user-friendly message.
        print(f"ERROR: An error occurred while generating the AI response: {e}")
        # In a real app, you might want to re-raise the exception to be handled by the API route.
        # For now, we'll return a clear error message.
        return f"I'm sorry, an error occurred while trying to connect to the AI service: {e}"


# --- Direct Testing Block ---
# This block allows us to test this file directly without running the whole web server.
# It will only run when you execute `python services/gemini_service.py` in the terminal.
if __name__ == "__main__":
    print("\n--- Running Direct Test of Gemini Service ---")
    
    # A simple test persona
    test_persona = "You are a helpful assistant who loves talking about space."
    
    # A simple test message
    test_message = "What is the largest planet in our solar system?"
    
    # Call the function
    ai_response = get_ai_response(test_persona, test_message)
    
    # Print the result
    print("\n--- TEST RESULT ---")
    print(f"Question: {test_message}")
    print(f"AI Response: {ai_response}")
    print("--- END OF TEST ---")