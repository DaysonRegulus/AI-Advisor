# Personal AI Advisor

**A next-generation, multi-agent personal development platform designed to provide holistic, intelligent guidance across all key areas of life.**

---

## 🚀 About The Project

The Personal AI Advisor is more than just a single chatbot. It's a sophisticated, multi-agent AI system designed to act as a personal team of expert coaches. The app provides a centralized platform where a user can interact with specialized AI agents, track their progress, and receive synthesized, cross-domain insights to foster growth and self-awareness.

This project was built to explore the power of modern Large Language Models (LLMs) beyond simple Q&A, creating an integrated system where multiple AIs work together under the supervision of a "Master Overseer" to provide coherent, contextual, and personalized advice. Which then evolved into this.

### Core Features

*   **🧠 Multi-Agent System:** Interact with a team of 7+ specialized AI experts, each with a unique persona and domain knowledge.
*   **🤖 Master Overseer AI:** A meta-level AI that analyzes all user interactions and journal entries to provide a synthesized daily summary, highlighting progress, challenges, and cross-domain insights.
*   **✍️ Interactive Journaling:** A "group chat" style journal where users can write their thoughts and receive insightful, encouraging comments from their AI team.
*   **🏆 Gamified Progression:** A robust Leveling and XP system that rewards positive actions like journaling, completing tasks, and achieving goals.
*   **📊 Future-Proof for Trackers:** Architected to easily incorporate various life-domain trackers (fitness, nutrition, habits, etc.).
*   **🔒 Secure & Private:** Built with security first, using Supabase's Row Level Security to ensure all user data is completely private and accessible only to them.

---

## 🛠️ Tech Stack

This project uses a modern, scalable, and efficient tech stack, chosen for its excellent developer experience and performance.

*   **Frontend:** [Flutter](https://flutter.dev/) - For building a beautiful, natively compiled mobile application for Android from a single codebase.
*   **Backend:** [FastAPI](https://fastapi.tiangolo.com/) (Python) - For creating a high-performance, asynchronous, and easy-to-use API.
*   **Database:** [Supabase](https://supabase.com/) (PostgreSQL) - An open-source Firebase alternative providing a database, authentication, and secure, auto-generated APIs.
*   **AI Integration:** [Google Gemini API](https://ai.google.dev/) (Gemini 2.5 Flash) - Leveraging a powerful and fast large language model with a massive context window for intelligent responses and deep memory.

![Tech Stack](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Tech Stack](https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white)
![Tech Stack](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)
![Tech Stack](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![Tech Stack](https://img.shields.io/badge/Google_Gemini-8E77F0?style=for-the-badge&logo=google&logoColor=white)


---

## ⚙️ Getting Started

To get a local copy up and running, follow these simple steps.

### Prerequisites

*   An account with [Supabase](https://app.supabase.com) (Free Tier).
*   An API Key from [Google AI Studio](https://aistudio.google.com/app/apikey) (Free Tier).
*   [Flutter SDK](https://docs.flutter.dev/get-started/install) installed and configured.
*   [Python](https://www.python.org/downloads/) (3.9+) installed.
*   An IDE like [VS Code](https://code.visualstudio.com/) with Flutter and Python extensions.
*   An Android Emulator setup via [Android Studio](https://developer.android.com/studio).

### Installation & Setup

#### 1. Backend Setup (FastAPI)

1.  **Clone the repository:**
    ```sh
    git clone https://github.com/DaysonRegulus/AI-Advisor.git
    cd AI-Advisor
    ```
2.  **Create and activate a Python virtual environment:**
    ```sh
    python -m venv venv
    source venv/bin/activate  # On Windows: venv\Scripts\activate
    ```
3.  **Install dependencies:**
    ```sh
    pip install -r requirements.txt
    ```
4.  **Set up environment variables:**
    *   Create a file named `.env` in the `backend/` directory.
    *   Get your credentials from Supabase (`Settings` -> `API`) and Google AI Studio.
    *   Add your credentials to the `.env` file:
      ```ini
      GEMINI_API_KEY="your_google_ai_studio_api_key"
      SUPABASE_URL="your_supabase_project_url"
      SUPABASE_KEY="your_supabase_service_role_key" 
      ```
      *Note: Use the `service_role` key for the backend to bypass RLS policies.*
5.  **Set up the Supabase Database:**
    *   Navigate to the SQL Editor in your Supabase project.
    *   Run the SQL scripts from the `/database_schema` directory in the repository to create tables and security policies. *(Coming soon)*.
6.  **Run the backend server:**
    ```sh
    uvicorn main:app --reload --host 0.0.0.0
    ```
    Your backend is now running at `http://localhost:8000`.

#### 2. Frontend Setup (Flutter)

1.  **Navigate to the frontend directory:**
    ```sh
    cd ../frontend
    ```
2.  **Get Flutter packages:**
    ```sh
    flutter pub get
    ```
3.  **Configure API connection:**
    *   Open the file `lib/api/api_service.dart`.
    *   Update the `_testUserId` with a user UID you create in your Supabase Auth dashboard.
    *   Ensure the `_baseUrl` is pointing to your machine's local IP for the emulator (`http://10.0.2.2:8000/api`).
4.  **Run the app:**
    *   Make sure your Android Emulator is running.
    *   Start the Flutter application:
    ```sh
    flutter run
    ```

---

## 🗺️ Roadmap

This project is under active development. Here's a look at the planned features:

*   [x] Core multi-agent chat functionality.
*   [x] "Master Overseer" daily summaries.
*   [x] Interactive Journaling with AI commentary.
*   [x] XP & Leveling system.
*   [x] Scalable AI Memory architecture.
*   [ ] **Trackers:** Implement trackers for Weight, Water, Fitness, and Habits.
*   [ ] **Skill Tree:** Design and build a deep, gamified skill tree for personal development.
*   [ ] **User Authentication:** Full sign-up, login, and profile management flow.
*   [ ] **Deployment:** Host the backend on a public cloud service like Render.
*   [ ] **UI/UX Polish:** Further refine the user interface and experience.

See the [open issues](https://github.com/DaysonRegulus/AI-Advisor/issues) for a full list of proposed features (and known issues).

---

## 🙏 Acknowledgements

This project would not have been possible without the incredible work of the teams behind:
*   [Flutter](https://flutter.dev/)
*   [FastAPI](https://fastapi.tiangolo.com/)
*   [Supabase](https://supabase.com/)
*   [Google's Gemini](https://ai.google.dev/)

---

## 📄 License

This project is licensed under the MIT License - see the `LICENSE.md` file for details.