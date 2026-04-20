#!/usr/bin/env python
"""
psai.py - ask an OpenAI-compatible endpoint for a PowerShell command.

Reads these environment variables:
  OPENAI_API_KEY   (required; any non-empty token for local servers)
  OPENAI_BASE_URL  (default: https://api.openai.com/v1)
  OPENAI_MODEL     (default: gpt-5-nano)
  OPENAI_TIMEOUT   (default: 30 seconds)

Usage:
  python psai.py <natural language request>
  python psai.py --wake jarvis jarvis list running services

Prints only the generated PowerShell command on stdout.
Errors go to stderr; exit codes: 0 ok, 1 LLM error, 2 config error.
"""

from __future__ import annotations

import json
import os
import re
import sys
import urllib.error
import urllib.request
from urllib.parse import urlparse

DEFAULT_BASE_URL = "https://api.openai.com/v1"
DEFAULT_MODEL = "gpt-5-nano"
DEFAULT_TIMEOUT = 30

SYSTEM_PROMPT = (
    "You are a PowerShell assistant on Windows 11. "
    "Given a user request in English, output ONLY the PowerShell command(s) to do it. "
    "Do NOT explain. Do NOT use markdown. Do NOT wrap in backticks. "
    "Prefer built-in PowerShell cmdlets."
)


class LLMError(RuntimeError):
    pass


def strip_wake(text: str, wake: str) -> str:
    if not wake:
        return text
    return re.sub(rf"^\s*{re.escape(wake)}\b\s*", "", text, count=1, flags=re.IGNORECASE)


def clean_output(cmd: str) -> str:
    cmd = cmd.strip()
    if cmd.startswith("```"):
        lines = cmd.splitlines()
        if lines and lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].startswith("```"):
            lines = lines[:-1]
        cmd = "\n".join(lines).strip()
    return cmd


def call_llm(
    user_text: str,
    *,
    base_url: str,
    api_key: str,
    model: str,
    timeout: int,
) -> str:
    parsed = urlparse(base_url)
    if parsed.scheme not in ("http", "https"):
        raise LLMError(
            f"OPENAI_BASE_URL must start with http:// or https:// (got {base_url!r})"
        )

    url = base_url.rstrip("/") + "/chat/completions"
    payload = {
        "model": model,
        "temperature": 0,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user_text},
        ],
    }
    data = json.dumps(payload).encode("utf-8")
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}",
    }
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")

    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = resp.read()
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8", errors="ignore")
        raise LLMError(f"HTTP {e.code} from {url}: {err_body}") from e
    except urllib.error.URLError as e:
        raise LLMError(f"Network error calling {url}: {e.reason}") from e

    try:
        obj = json.loads(body.decode("utf-8"))
        return clean_output(obj["choices"][0]["message"]["content"])
    except (json.JSONDecodeError, KeyError, IndexError, TypeError) as e:
        snippet = body[:500].decode("utf-8", errors="replace")
        raise LLMError(f"Unexpected response: {snippet!r}") from e


def parse_argv(argv):
    wake = ""
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--wake":
            if i + 1 >= len(argv):
                raise ValueError("--wake requires a value")
            wake = argv[i + 1]
            i += 2
            continue
        if a == "--":
            i += 1
            break
        break
    text = " ".join(argv[i:]).strip()
    return wake, text


def main(argv=None) -> int:
    if argv is None:
        argv = sys.argv[1:]

    try:
        wake, text = parse_argv(argv)
    except ValueError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2

    if not text:
        print(
            "Usage: python psai.py [--wake WORD] <natural language request>\n"
            "Example: python psai.py list running services",
            file=sys.stderr,
        )
        return 2

    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        print(
            'ERROR: OPENAI_API_KEY is not set. '
            'Set it with:  setx OPENAI_API_KEY "sk-..."  then reopen PowerShell.',
            file=sys.stderr,
        )
        return 2

    base_url = os.getenv("OPENAI_BASE_URL", DEFAULT_BASE_URL)
    model = os.getenv("OPENAI_MODEL", DEFAULT_MODEL)
    try:
        timeout = int(os.getenv("OPENAI_TIMEOUT", str(DEFAULT_TIMEOUT)))
    except ValueError:
        timeout = DEFAULT_TIMEOUT

    user_text = strip_wake(text, wake)

    try:
        print(
            call_llm(
                user_text,
                base_url=base_url,
                api_key=api_key,
                model=model,
                timeout=timeout,
            )
        )
    except LLMError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
