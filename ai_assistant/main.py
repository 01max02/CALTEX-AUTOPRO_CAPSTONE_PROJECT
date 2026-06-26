import traceback
import uuid
import re as _re
from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from schemas import ChatRequest, ChatResponse, CustomerChatRequest, SessionInfoResponse
from client import chat as llm_chat
from intent_classifier import classify_and_run
from session_store import (
    get_history, append_turn, clear_session, session_info, active_session_count
)

app = FastAPI(
    title="Caltex AutoPro AI",
    description="AI assistant with server-side conversational memory",
)


# ── Rate-limit helper ─────────────────────────────────────────────────────────

def _parse_rate_limit_reset(error_message: str) -> str:
    """
    Extract the reset time from a Groq RateLimitError message.
    e.g. 'Please try again in 15m46.944s' → 'about 15 minutes'
         'Please try again in 1h30m.'     → 'about 1 hour and 30 minutes'
    """
    hours   = _re.search(r'in\s+(\d+)h', error_message)
    minutes = _re.search(r'in\s+(?:\d+h\s*)?(\d+)m', error_message)

    parts = []
    if hours:
        h = int(hours.group(1))
        parts.append(f"{h} hour{'s' if h != 1 else ''}")
    if minutes:
        m = int(minutes.group(1))
        parts.append(f"{m} minute{'s' if m != 1 else ''}")

    if parts:
        return "about " + " and ".join(parts)
    return "some time"


def _rate_limit_reply(error_message: str) -> dict:
    """Build a structured rate-limit response the frontends can detect."""
    reset_in = _parse_rate_limit_reset(error_message)
    return {
        "rate_limited": True,
        "reply": (
            f"⚠️ The AI service has reached its daily usage limit (Groq free tier).\n\n"
            f"It will automatically reset in {reset_in}.\n\n"
            f"Please try again later."
        ),
        "reset_in": reset_in,
    }


def _is_rate_limit(exc: Exception) -> bool:
    cls_name = type(exc).__name__.lower()
    return "ratelimit" in cls_name or "rate_limit" in cls_name or "429" in str(exc)


# ── Health ────────────────────────────────────────────────────────────────────

@app.get("/health")
def health():
    return {
        "status":          "ok",
        "role":            "admin",
        "active_sessions": active_session_count(),
    }


# ── Session management ────────────────────────────────────────────────────────

@app.get("/session/{session_id}", response_model=SessionInfoResponse)
def get_session_info(session_id: str):
    """Return metadata about a session (number of stored turns, last active)."""
    return session_info(session_id)


@app.delete("/session/{session_id}")
def delete_session(session_id: str):
    """Clear all stored history for a session."""
    clear_session(session_id)
    return {"success": True, "session_id": session_id, "message": "Session cleared"}


# ── Admin chat ────────────────────────────────────────────────────────────────

@app.post("/admin/chat", response_model=ChatResponse)
def admin_chat(req: ChatRequest):
    """
    Admin AI chat with server-side conversational memory.

    Flow:
      1. Resolve or create a session_id.
      2. Load stored history for that session from the in-memory store.
      3. Merge with any client-supplied history (client history takes precedence
         for the current turn; server history provides the long-term context).
      4. Run the fast classifier, then the LLM tool-calling loop.
      5. Append the new user/assistant pair to the session store.
      6. Return the reply AND the session_id so the client sends it back next time.
    """
    # 1. Resolve session
    session_id = req.session_id or str(uuid.uuid4())

    try:
        # 2. Load server-side history
        server_history = get_history(session_id)

        # 3. Build effective history: server history is the base; any client-supplied
        #    history (legacy clients) is appended after deduplication.
        effective_history = _merge_history(server_history, req.history)

        # 4. Run the fast classifier first (cheaper path for obvious queries)
        fast_path = classify_and_run(req.message)
        if fast_path:
            phrasing_prompt = (
                f"The user asked: \"{req.message}\"\n\n"
                f"Here is the exact data retrieved from the database:\n{fast_path['result']}\n\n"
                f"Answer the user's question using ONLY this data. "
                f"Do not recalculate anything."
            )
            result = llm_chat(phrasing_prompt, history=effective_history)
            reply = result["reply"]
            tool_calls_out = [fast_path]
        else:
            result = llm_chat(req.message, history=effective_history)
            reply = result["reply"]
            tool_calls_out = result["tool_calls"]

        # 5. Persist this exchange to the session store
        append_turn(session_id, req.message, reply)

        return ChatResponse(
            reply=reply,
            session_id=session_id,
            tool_calls=tool_calls_out,
        )

    except Exception as e:
        if _is_rate_limit(e):
            rl = _rate_limit_reply(str(e))
            return ChatResponse(
                reply=rl["reply"],
                session_id=session_id,
                rate_limited=True,
                reset_in=rl["reset_in"],
            )
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


# ── Admin report ──────────────────────────────────────────────────────────────

@app.post("/admin/report")
def admin_report(report_type: str, format: str = "pdf"):
    """
    Generate a PDF or Excel report directly from Firestore data.

    Query params:
        report_type: inventory | issuance | maintenance | vehicles | bookings
        format:      pdf | excel  (default: pdf)
    """
    try:
        import io
        from report_generator import build_report, REPORT_CONFIG

        if report_type not in REPORT_CONFIG:
            raise HTTPException(
                status_code=400,
                detail=f"Unknown report_type '{report_type}'. "
                       f"Use: {', '.join(REPORT_CONFIG.keys())}"
            )
        fmt = format.lower().replace("xlsx", "excel")
        if fmt not in ("pdf", "excel"):
            raise HTTPException(status_code=400, detail="format must be 'pdf' or 'excel'")

        data  = build_report(report_type, fmt)
        title = REPORT_CONFIG[report_type]["title"].replace(" ", "_")

        if fmt == "pdf":
            media_type = "application/pdf"
            filename   = f"{title}.pdf"
        else:
            media_type = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            filename   = f"{title}.xlsx"

        return StreamingResponse(
            io.BytesIO(data),
            media_type=media_type,
            headers={"Content-Disposition": f'attachment; filename="{filename}"'},
        )

    except HTTPException:
        raise
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


# ── Customer chat ─────────────────────────────────────────────────────────────

CUSTOMER_SYSTEM_PROMPT = """You are the personal vehicle assistant for a Caltex AutoPro customer.

You help customers with questions about THEIR OWN vehicles and service history only.

What you can help with:
- Their registered vehicles and current PMS (Preventive Maintenance Schedule) status
- Their completed service history and how much they have spent
- Their upcoming or past service bookings / appointments
- Service pricing and cost estimates (e.g. "how much is a change oil?")
- What services are available and their prices

Rules — follow these strictly:
1. You only have access to data belonging to the logged-in customer. Never mention or reveal other customers' data.
2. Never show stock levels, supplier data, issuance records, delivery records, or any admin-only information.
3. Never generate or offer PDF/Excel reports.
4. Never reveal staff names beyond what appears in a service record the customer already owns.
5. Always call the appropriate tool before answering. Never invent numbers, dates, or records.
6. If a tool returns no data, say so plainly — do not make up information.
7. Be warm, helpful, and conversational. You are speaking directly to a vehicle owner.
8. For cost estimates, always call estimate_service_cost with the service names — do not guess prices.
9. If the customer asks about something outside your scope (e.g. inventory, other users), politely explain you can only help with their own vehicles and services.
10. Use conversation history to understand follow-up questions. If the user says "what about that vehicle?" or "tell me more", refer to the previous context.

CRITICAL — Reformatting follow-ups:
If the user says "make it a list", "number them", "simplify", or any similar reformatting request —
DO NOT call any tools. Simply reformat your PREVIOUS answer in the requested style.

Keyword mappings:
- "my vehicles", "my fleet", "my cars" → get_my_vehicles
- "service history", "past services", "how much have I spent", "maintenance records" → get_my_service_history
- "PMS", "when is my next service", "overdue", "due soon", "maintenance schedule" → get_my_pms_status
- "my bookings", "my appointments", "upcoming service" → get_my_bookings
- "how much is", "price of", "cost of", "service prices", "what services" → get_service_prices or estimate_service_cost
- "estimate", "how much would it cost" → estimate_service_cost
"""


def _run_customer_chat(message: str, customer_uid: str, customer_name: str,
                       history: list[dict]) -> dict:
    """Core customer LLM loop with tool-calling."""
    import json
    from groq import Groq, BadRequestError
    from config import settings
    from customer_tools import CUSTOMER_TOOL_SCHEMAS, CUSTOMER_TOOL_FUNCTIONS

    client = Groq(api_key=settings.GROQ_API_KEY)

    def _call(msgs, tools=None):
        kwargs = {"model": settings.GROQ_MODEL, "messages": msgs}
        if tools:
            kwargs["tools"] = tools
        return client.chat.completions.create(**kwargs)

    def _strip_null(raw: str) -> dict:
        if not raw or not raw.strip():
            return {}
        try:
            args = json.loads(raw)
        except json.JSONDecodeError:
            return {}
        if not isinstance(args, dict):
            return {}
        return {k: v for k, v in args.items() if v is not None and v != ""}

    messages = [{"role": "system", "content": CUSTOMER_SYSTEM_PROMPT}]
    messages.extend(history)
    messages.append({"role": "user", "content": message})

    tool_log    = []
    final_reply = ""

    for _ in range(5):
        try:
            response = _call(messages, tools=CUSTOMER_TOOL_SCHEMAS)
        except BadRequestError as e:
            import logging
            logging.warning("Customer Groq BadRequestError: %s", e)
            try:
                fb = _call(messages)
                return {
                    "reply": fb.choices[0].message.content
                             or "I couldn't retrieve that information. Please try rephrasing.",
                    "tool_calls": tool_log,
                }
            except Exception:
                return {
                    "reply": "I couldn't retrieve that information. Please try rephrasing.",
                    "tool_calls": tool_log,
                }

        msg  = response.choices[0].message
        asst: dict = {"role": "assistant", "content": msg.content or ""}
        if msg.tool_calls:
            asst["tool_calls"] = [tc.model_dump() for tc in msg.tool_calls]
        messages.append(asst)

        if not msg.tool_calls:
            final_reply = msg.content or ""
            break

        for call in msg.tool_calls:
            fn_name = call.function.name
            fn_args = _strip_null(call.function.arguments or "")
            fn      = CUSTOMER_TOOL_FUNCTIONS.get(fn_name)

            if fn is None:
                result = {"error": f"Unknown tool '{fn_name}'"}
            else:
                try:
                    result = fn(
                        customer_uid=customer_uid,
                        customer_name=customer_name,
                        **fn_args,
                    )
                except Exception as e:
                    result = {"error": str(e)}

            tool_log.append({"tool": fn_name, "args": fn_args, "result": result})
            messages.append({
                "role":         "tool",
                "tool_call_id": call.id,
                "content":      json.dumps(result),
            })
    else:
        final_reply = "Sorry, I had trouble completing that request. Please try again."

    return {"reply": final_reply, "tool_calls": tool_log}


@app.post("/customer/chat", response_model=ChatResponse)
def customer_chat_endpoint(req: CustomerChatRequest):
    """
    Customer AI chat with server-side conversational memory.
    Scoped strictly to the logged-in customer's own data.

    Requires:
        message:       the customer's question
        customer_uid:  Firebase Auth UID
        customer_name: display name (matched against Firestore owner field)
        session_id:    optional; auto-generated and returned if omitted
        history:       optional client-side history (merged with server memory)
    """
    if not req.customer_uid or not req.customer_name:
        raise HTTPException(
            status_code=400,
            detail="customer_uid and customer_name are required",
        )

    # Use customer_uid as the natural session key so each customer
    # automatically has their own persistent memory across devices/sessions.
    session_id = req.session_id or f"customer-{req.customer_uid}"

    try:
        server_history   = get_history(session_id)
        effective_history = _merge_history(server_history, req.history)

        result = _run_customer_chat(
            message=req.message,
            customer_uid=req.customer_uid,
            customer_name=req.customer_name,
            history=effective_history,
        )
        reply = result["reply"]

        append_turn(session_id, req.message, reply)

        return ChatResponse(
            reply=reply,
            session_id=session_id,
            tool_calls=result["tool_calls"],
        )

    except Exception as e:
        if _is_rate_limit(e):
            rl = _rate_limit_reply(str(e))
            return ChatResponse(
                reply=rl["reply"],
                session_id=session_id,
                rate_limited=True,
                reset_in=rl["reset_in"],
            )
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


# ── Shared helpers ────────────────────────────────────────────────────────────

def _merge_history(server: list[dict], client: list[dict] | None) -> list[dict]:
    """
    Merge server-side stored history with optional client-supplied history.

    Strategy:
    - Server history is the authoritative long-term memory.
    - If the client sends history too (legacy / transitional clients), we use
      whichever is longer, preferring server history on tie.
    - Strips any messages missing a 'role' key (Groq rejects them).
    - Caps at 30 messages (15 turns) to keep context windows manageable.
    """
    clean_server = [m for m in server if isinstance(m, dict) and "role" in m]
    clean_client = [m for m in (client or []) if isinstance(m, dict) and "role" in m]

    # Use the longer source — server history wins on tie
    base = clean_server if len(clean_server) >= len(clean_client) else clean_client

    # Cap at 30 messages (keep most recent)
    return base[-30:] if len(base) > 30 else base
