"""
Reply verifier.

After the LLM produces its final answer, this module checks that every number
in the reply is actually supported by data that came back from tool calls.
Numbers that the model invented or miscalculated are flagged so the caller can
trigger a correction pass.
"""
import re


def _extract_numbers(text: str) -> set[str]:
    """Return all numeric strings (int or float, with optional commas) found in text."""
    # Matches: 1,234,567  |  1234567  |  3.14  |  1,234.56
    return set(re.findall(r"\b\d[\d,]*(?:\.\d+)?\b", text))


def _flatten_numbers(obj, found: set[str] | None = None) -> set[str]:
    """Recursively extract every numeric value from a nested dict/list structure."""
    if found is None:
        found = set()
    if isinstance(obj, dict):
        for v in obj.values():
            _flatten_numbers(v, found)
    elif isinstance(obj, list):
        for item in obj:
            _flatten_numbers(item, found)
    elif isinstance(obj, (int, float)):
        # Normalise to the same string format the regex above would produce
        found.add(str(obj).replace(".0", "") if str(obj).endswith(".0") else str(obj))
        found.add(str(obj))  # keep both forms for flexibility
    return found


def verify_reply(reply: str, tool_call_log: list[dict]) -> dict:
    """
    Check that every number in *reply* appears in at least one tool result.

    Parameters
    ----------
    reply : str
        The LLM's final answer text.
    tool_call_log : list[dict]
        List of dicts with at least a ``"result"`` key (the value returned by
        each tool call).  Shape: [{"tool": ..., "args": ..., "result": ...}, ...]

    Returns
    -------
    dict with keys:
        verified (bool)          – True if no unsupported numbers found.
        unsupported_numbers (list[str])
        source_numbers (list[str])
    """
    # Collect all numbers that came from tools
    source_numbers: set[str] = set()
    for entry in tool_call_log:
        _flatten_numbers(entry.get("result", {}), source_numbers)

    # Numbers the model wrote in its reply
    reply_numbers = _extract_numbers(reply)

    # A reply number is "unsupported" if it doesn't appear anywhere in the
    # source numbers. We also allow formatted variants (e.g. "1,234" ↔ "1234").
    def _normalise(n: str) -> str:
        return n.replace(",", "")

    normalised_source = {_normalise(n) for n in source_numbers}

    unsupported = [
        n for n in reply_numbers
        if _normalise(n) not in normalised_source
    ]

    return {
        "verified": len(unsupported) == 0,
        "unsupported_numbers": unsupported,
        "source_numbers": sorted(source_numbers),
    }
