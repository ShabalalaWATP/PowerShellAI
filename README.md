# powershellai

Ask an OpenAI-compatible LLM (cloud or local) for PowerShell commands, straight from your prompt.

Two commands:

- **`jarvis`** - generate a PowerShell command, show it, and run it. Anything that isn't purely read-only is blocked behind a confirmation prompt.
- **`friday`** - generate a PowerShell command, show it, and copy it to the clipboard. Never runs it.

Both are thin PowerShell wrappers around one ~170-line Python file, so everything stays easy to inspect and audit.

---

## Why this exists

You know what you want Windows to do, but you've forgotten the exact cmdlet. A quick

```powershell
jarvis show me top 10 processes by memory
```

beats a trip to Stack Overflow. Because the LLM returns executable code, the tool is deliberately cautious:

- `jarvis` parses the model's output with the PowerShell AST and checks every invoked cmdlet. Read-only commands (`Get-*`, `Select-*`, `Where-Object`, ...) run without asking. Anything that mutates state asks first.
- `friday` never executes anything.
- Every interaction is logged to `%LOCALAPPDATA%\psai\history.jsonl` so you can review what ran.

---

## Files

| File | Purpose |
| --- | --- |
| [psai.py](psai.py) | Calls the OpenAI-compatible `/v1/chat/completions` endpoint. Prints only the generated command. No third-party dependencies. |
| [powershellai.ps1](powershellai.ps1) | Defines `jarvis`, `friday`, and the AST-based safety check. |

---

## Prerequisites

- Windows 10 or 11 with PowerShell 5.1+ (or PowerShell 7).
- Python 3.8+ on `PATH` (`python --version` must work).
- An OpenAI-compatible HTTP endpoint. Tested against:
  - `https://api.openai.com/v1`
  - LM Studio, Ollama (with its OpenAI shim), vLLM, text-generation-webui, etc.

The Python side uses only the standard library - no `pip install` required.

---

## Setup

### 1. Clone

```powershell
git clone https://github.com/shabalalawatp/powershellai.git
cd powershellai
```

### 2. Set environment variables

Both files read the same four variables:

| Variable | Default | Notes |
| --- | --- | --- |
| `OPENAI_API_KEY` | *(unset - required)* | The script refuses to run without it. For local servers any non-empty string works. |
| `OPENAI_BASE_URL` | `https://api.openai.com/v1` | Point at a local server for offline use. |
| `OPENAI_MODEL` | `gpt-5-nano` | Any model the endpoint serves. |
| `OPENAI_TIMEOUT` | `30` | Request timeout, seconds. |

**Cloud (real OpenAI):**

```powershell
setx OPENAI_API_KEY "sk-your-real-key"
setx OPENAI_BASE_URL "https://api.openai.com/v1"
setx OPENAI_MODEL "gpt-5-nano"
```

**Local (e.g. LM Studio on port 1234):**

```powershell
setx OPENAI_API_KEY "sk-local-test"
setx OPENAI_BASE_URL "http://127.0.0.1:1234/v1"
setx OPENAI_MODEL "your-local-model-name"
```

`setx` writes the variables to the user registry - **open a new PowerShell window** before the next step so they take effect.

> Never paste your key into the source. Both scripts read it exclusively from the environment.

### 3. Load the PowerShell functions

One-off (this session only):

```powershell
. .\powershellai.ps1
```

Permanent (every new PowerShell has `jarvis` and `friday` ready):

```powershell
notepad $PROFILE
```

Add one line with the real path you cloned into:

```powershell
. "C:\path\to\powershellai\powershellai.ps1"
```

Save, then reload:

```powershell
. $PROFILE
```

The wrapper resolves `psai.py` via `$PSScriptRoot`, so you can move the folder anywhere as long as both files stay together.

---

## Usage

### `friday` - show only

```powershell
friday list services that are stopped
```

```
friday generated:
Get-Service | Where-Object Status -eq 'Stopped'
```

The command is on your clipboard. Nothing runs.

### `jarvis` - generate and run

A read-only request runs immediately:

```powershell
jarvis show me top 10 processes by memory
```

```
jarvis generated:
Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 10
Running...
<process table>
```

A mutating request asks first:

```powershell
jarvis delete all .tmp files under my Downloads
```

```
jarvis generated:
Get-ChildItem $env:USERPROFILE\Downloads -Filter *.tmp -Recurse | Remove-Item -Force
Risky cmdlets detected: Remove-Item
Run anyway? (type 'yes' to confirm):
```

Only a full `yes` proceeds - a bare `y` aborts. Anything that isn't obviously read-only but isn't explicitly dangerous falls into a third bucket and gets a gentler `y/N` prompt.

### Switches

| Switch | Applies to | Effect |
| --- | --- | --- |
| `-Yes` | `jarvis` | Skip the confirmation prompt this one time. |
| `-NoClipboard` | both | Don't overwrite the clipboard. |
| `-NoLog` | both | Don't append to the audit log. |

Example:

```powershell
jarvis -Yes restart the spooler service
```

### Audit log

Each call appends one JSON line to `%LOCALAPPDATA%\psai\history.jsonl`:

```json
{"ts":"2026-04-20T18:32:11.0000000+01:00","mode":"jarvis","prompt":"show running services","command":"Get-Service | Where-Object Status -eq 'Running'","action":"run"}
```

`action` is one of `run`, `print`, `block-dangerous`, `block-unknown`, `block-parseerror`.

Tail it live in another window:

```powershell
Get-Content $env:LOCALAPPDATA\psai\history.jsonl -Wait -Tail 5
```

---

## How the safety check works

`powershellai.ps1` parses the model's output with `[System.Management.Automation.Language.Parser]::ParseInput` and walks the AST to find every `CommandAst`. Each invoked cmdlet is classified:

- **Safe** - matches a pattern like `Get-*`, `Select-*`, `Where-Object`. A command made entirely of safe cmdlets runs without prompting.
- **Dangerous** - matches an explicit name or alias (`Remove-Item`, `rm`, `ri`, `Stop-Computer`, `Invoke-Expression`, `iex`, `Invoke-WebRequest`, ...). Triggers the strict `type 'yes'` prompt.
- **Unknown** - everything else. Triggers a lighter `y/N` prompt.

This catches the substring-match bypasses a naive blocklist misses: aliases (`ri`, `rm`, `iex`), `Remove-Item` inside a pipeline, `IEX (iwr ...)` download-and-run, etc.

The AST check is **not a security boundary**. An LLM with enough rope can still compose something unpleasant, and `Invoke-Expression` on any LLM output is inherently risky - treat `jarvis` the way you'd treat any command you pasted from the internet. That's what `friday` is for.

---

## Using `psai.py` directly

No PowerShell required:

```powershell
python psai.py list running services
python psai.py --wake jarvis jarvis list running services
```

Exit codes:

| Code | Meaning |
| --- | --- |
| 0 | Command printed on stdout. |
| 1 | LLM call failed (HTTP / network / malformed response). |
| 2 | Config error (missing `OPENAI_API_KEY`, bad URL, no prompt). |

---

## Troubleshooting

**`ERROR: OPENAI_API_KEY is not set`**
You ran `setx` but this PowerShell window started before that. Open a new one, or for a one-off: `$env:OPENAI_API_KEY = "sk-..."`.

**`jarvis : The term 'jarvis' is not recognized`**
The script isn't loaded. Dot-source it: `. "C:\path\to\powershellai.ps1"`, or add that line to `$PROFILE`.

**`psai.py not found at <path>`**
`powershellai.ps1` and `psai.py` have to live in the same folder. `$PSScriptRoot` resolves to the `.ps1`'s own directory.

**Model returns prose / markdown despite the system prompt**
`psai.py` strips ``` ``` ``` fences automatically. If it still leaks, try a more capable model or lower temperature further.

**Local endpoint returns `404 /chat/completions`**
Your server uses a different path. Check `GET <BASE_URL>/models` first; if that 404s too, `OPENAI_BASE_URL` is wrong.

---

## Security notes

- The API key is read from the environment only - never commit it.
- `jarvis` executes LLM output. The AST check flags obvious destructive calls, but it is not a sandbox.
- The audit log stores your prompts and generated commands in plaintext. If that matters, pass `-NoLog` or relocate `%LOCALAPPDATA%\psai`.
