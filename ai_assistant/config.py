import os
from dotenv import load_dotenv

load_dotenv()


class Settings:
    # Groq — fast cloud inference (OpenAI-compatible API). Chosen because local
    # hardware (laptop, no dedicated GPU) can't run a 14B+ model fast enough for
    # the multi-step tool-calling loop this app uses.
    # NOTE: this sends data (inventory/sales/PMS queries) to Groq's servers.
    # Keep customer PII out of prompts where possible if that's a concern.
    GROQ_API_KEY: str = os.getenv("GROQ_API_KEY", "")
    GROQ_MODEL: str = os.getenv("GROQ_MODEL", "llama-3.3-70b-versatile")
    # Alt: "llama-3.1-8b-instant" — much faster, less reliable at instruction-following.

    # Firebase / Firestore
    FIREBASE_CREDENTIALS_PATH: str = os.getenv(
        "FIREBASE_CREDENTIALS_PATH", "./serviceAccountKey.json"
    )

    # App
    APP_ROLE: str = "admin"  # this service instance is the Admin AI


settings = Settings()