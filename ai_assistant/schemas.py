from pydantic import BaseModel


class ChatRequest(BaseModel):
    message: str
    session_id: str | None = None      # server-side memory key; auto-generated if omitted
    history: list[dict] | None = None  # optional client-side history (merged with server memory)


class ChatResponse(BaseModel):
    reply: str
    session_id: str                    # always returned so the client can send it back
    tool_calls: list[dict] = []
    rate_limited: bool = False         # True when Groq daily token limit is reached
    reset_in: str = ""                 # human-readable reset time e.g. "about 15 minutes"


class CustomerChatRequest(BaseModel):
    message: str
    customer_uid: str                  # Firebase Auth UID (used for booking queries)
    customer_name: str                 # Display name (used for Firestore owner field matching)
    session_id: str | None = None
    history: list[dict] | None = None


class SessionInfoResponse(BaseModel):
    session_id: str
    turns: int
    exists: bool
