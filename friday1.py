#!/usr/bin/env python
"""
friday.py
Same as jarvis.py but with wake word 'friday' and typically used for
'just show me the command' flows.
"""

import os
import sys
import json
import urllib.request
import urllib.error

WAKE_WORD = "friday"

BASE_URL = os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1")
API_KEY = os.getenv("OPENAI_API_KEY", "sk-local-test")
MODEL = os.getenv("OPENAI_MODEL", "gpt-5-nano")

SYSTEM_PROMPT = (
    "You are a PowerShell assistant on Windows 11. "
    "Given a user request in English, output ONLY the PowerShell command(s) to do it. "
    "Do NOT explain. Do NOT use markdown. Do NOT wrap in backticks. "
    "Prefer built-in PowerShell cmdlets."
)

def strip_wake(text: str) -> str:
    text = text.lstrip()
    if text.lower().startswith(WAKE_WORD):
        return text[len(WAKE_WORD):].lstrip()
    return text

def call_llm(user_text: str) -> str:
    url = BASE_URL.rstrip("/") + "/chat/completions"

    payload = {
        "model": MODEL,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user_text},
        ]
    }

    data = json.dumps(payload).encode("utf-8")
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {API_KEY}",
    }

    req = urllib.request.Request(url, data=data, headers=headers, method="POST")

    try:
        with urllib.request.urlopen(req) as resp:
            body = resp.read()
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8", errors="ignore")
        print(f"ERROR calling LLM: {e.code} - {err_body}")
        sys.exit(1)
    except urllib.error.URLError as e:
        print(f"ERROR calling LLM: {e}")
        sys.exit(1)

    obj = json.loads(body.decode("utf-8"))
    try:
        return obj["choices"][0]["message"]["content"].strip()
    except Exception:
        print("ERROR: unexpected response:", obj)
        sys.exit(1)

def main():
    if len(sys.argv) < 2:
        print('Usage: python friday.py "friday list running services"')
        sys.exit(1)

    user_text = " ".join(sys.argv[1:])
    user_text = strip_wake(user_text)

    cmd = call_llm(user_text)
    print(cmd)

if __name__ == "__main__":
    main()
