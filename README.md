<br/>
<div align="center">
  <!-- You can replace this with a real logo file later -->
  <img src="frontend\assets\icons\icon.png" alt="Clarity AI Logo" width="100">
  <h1 align="center">Clarity AI</h1>
  <p align="center">
    Your Personal Multi-Agent AI Companion for Holistic Self-Improvement.
    <br />
    <a href="#-key-features"><strong>Explore the features »</strong></a>
    <br />
    <br />
  </p>
</div>

<!-- Badges -->
<div align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/Python-3.9+-blue?logo=python" alt="Python">
  <img src="https://img.shields.io/badge/Backend-FastAPI-green?logo=fastapi" alt="FastAPI">
  <img src="https://img.shields.io/badge/Database-Supabase-green?logo=supabase" alt="Supabase">
  <img src="https://img.shields.io/badge/AI-Google%20Gemini-purple" alt="Gemini">
  <img src="https://img.shields.io/badge/Deployment-Fly.io-violet?logo=fly" alt="Fly.io">
  <img src="https://img.shields.io/badge/License-MIT-lightgrey" alt="License">
</div>

---

**Clarity AI** is a next-generation personal wellness application designed to provide holistic guidance and insights across all facets of life. It moves beyond single-purpose chatbots by integrating a suite of specialized AI coaches; from a personal trainer to a financial advisor; into a single, cohesive platform. Through reflective journaling, real-time feedback, and comprehensive progress tracking, Clarity AI empowers users to understand themselves better and take actionable steps towards their goals.

This project is a full-stack, production-ready application showcasing a modern, scalable architecture using Flutter for the cross-platform mobile app and a high-performance FastAPI backend, all deployed on a global edge network.

<br/>

## ✨ Key Features

*   **Multi-Agent AI Coaching:** Interact with a team of specialized AI experts, each with a unique persona and knowledge domain, including:
    *   Personal Trainer & Nutritionist
    *   Mental Health Coach
    *   Financial Advisor
    *   Career Coach
    *   ...and more.

*   **Reflective Journaling with Real-Time Feedback:** Write journal entries and receive instant, insightful, and encouraging comments from your team of AI coaches, delivered via a live WebSocket connection.

*   **Advanced Scalable AI Memory:** A custom-built "Cumulative Summary + Active Window" memory system allows AI agents to maintain long-term context on your journey, providing deeply personalized and relevant advice without exceeding context limits.

*   **Comprehensive Health & Wellness Dashboard:** Track your daily progress at a glance with an integrated dashboard for:
    *   Water Intake
    *   Nutritional Analysis (Calories, Macros, Micros)
    *   Weight Logging with Historical Charts

*   **Gamification & Engagement System:** Stay motivated by earning XP for completing tasks like journaling and logging meals. Level up and track your progress through a rewarding gamification layer.

*   **Secure Authentication & User Data Isolation:** A complete, secure authentication system (Login, Signup, Session Management) built on Supabase, with Row Level Security (RLS) enabled at the database level to guarantee that user data is strictly isolated and protected.

<!--
## 📸 Screenshots

*(This section would feature high-quality screenshots of the application)*

| Dashboard                                | Journal with AI Comments                  | Agent Chat                               |
| ---------------------------------------- | ----------------------------------------- | ---------------------------------------- |
| *(Image of the main HomeScreen)*        | *(Image of the JournalScreen)*            | *(Image of the AgentChatScreen)*         |
| A holistic view of your daily progress.  | Receive instant feedback on your thoughts. | Get personalized advice from an expert.  |
-->

## 🛠️ Technical Architecture

This project is architected as a modern, decoupled full-stack application, with a clear separation of concerns between the frontend, backend, and database services.

| Component         | Technology                                                                          | Description                                                                                             |
| ----------------- | ----------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| **Mobile App**    | [Flutter](https://flutter.dev/)                                                     | A cross-platform UI toolkit for building the native iOS and Android application from a single codebase. |
| **State Mgmt**    | [Provider](https://pub.dev/packages/provider)                                       | For clean, scalable, and reactive state management across the Flutter application.                      |
| **Backend API**   | [FastAPI](https://fastapi.tiangolo.com/) (Python)                                   | A high-performance, asynchronous web framework for building the RESTful API and WebSocket services.   |
| **AI Model**      | [Google Gemini](https://deepmind.google/technologies/gemini/)                       | Powers the intelligence and conversational abilities of all AI agents.                                  |
| **Database**      | [Supabase](https://supabase.com/) (PostgreSQL)                                      | The backend-as-a-service provider for the Postgres database, user authentication, and RLS.              |
| **Real-time**     | WebSockets                                                                          | Enables instant, bi-directional communication for pushing live AI journal comments to the client.       |
| **Deployment**    | [Docker](https://www.docker.com/), [Fly.io](https://fly.io/)                         | The backend is containerized with Docker and deployed globally on Fly.io's edge computing platform.     |

## 🚀 Getting Started

Follow these instructions to get a local copy of the project up and running for development and testing purposes.

### Prerequisites

Ensure you have the following tools installed on your machine:
*   [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.x or higher)
*   [Python](https://www.python.org/downloads/) (version 3.9 or higher)
*   [Docker Desktop](https://www.docker.com/products/docker-desktop/)
*   [Fly.io CLI (`flyctl`)](https://fly.io/docs/hands-on/install-flyctl/)

### 1. Backend Setup

The backend server must be running for the frontend to communicate with.

```bash
# 1. Clone the repository
git clone https://github.com/DaysonRegulus/AI-Advisor.git
cd AI-Advisor/backend

# 2. Create and activate a Python virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: .\venv\Scripts\activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. Set up your environment secrets
# Create a .env file by copying the template
cp .env.template .env

# Now, open the .env file and fill in your actual secret keys from
# your Supabase and Google AI project dashboards.

# 5. Run the development server
uvicorn main:app --reload --host 0.0.0.0
```
> **Note:** The server will be running at `http://127.0.0.1:8000`. You can access the interactive API documentation at `http://127.0.0.1:8000/docs`.

### 2. Frontend Setup

With the backend running, you can now launch the Flutter application.

```bash
# 1. Navigate to the frontend directory
cd ../frontend

# 2. Set up your environment configuration
# Create a config.dart file from the template
# (You will need to create the file and copy the contents manually)
# File: lib/config.dart

# 3. In lib/config.dart, ensure the baseUrl for local development is active:
# static const String baseUrl = 'http://10.0.2.2:8000';

# 4. Get all Flutter dependencies
flutter pub get

# 5. Run the application on your connected device or emulator
flutter run
```

## ☁️ Deployment

The backend is configured for production deployment on [Fly.io](https://fly.io/) using Docker.

1.  **Containerize the App:** The included `Dockerfile` uses a multi-stage build to create a lightweight, optimized production image.
2.  **Set Secrets:** Production secrets are managed securely using Fly.io's encrypted secret store. They are never hardcoded or included in the Docker image.
    ```bash
    fly secrets set SUPABASE_URL="..." GEMINI_API_KEY="..." ...
    ```
3.  **Deploy:** A single command builds the image, pushes it to the registry, and deploys it globally.
    ```bash
    fly deploy
    ```

## 🗺️ Roadmap

This project is an active work-in-progress. Future enhancements include:

*   [x] Core multi-agent chat functionality.
*   [x] "Master Overseer" daily summaries.
*   [x] Interactive Journaling with AI commentary.
*   [x] XP & Leveling system.
*   [x] Scalable AI Memory architecture.
*   [x] **Trackers:** Implement trackers for Weight, Water, Fitness, and Habits.
*   [x] **User Authentication:** Full sign-up, login, and profile management flow.
*   [x] **Deployment:** Host the backend on a public cloud service like Render.
*   [ ] **Skill Tree:** Design and build a deep, gamified skill tree for personal development.
*   [ ] **UI/UX Polish:** Further refine the user interface and experience.

## 📄 License

This project is distributed under the MIT License. See `LICENSE` for more information.