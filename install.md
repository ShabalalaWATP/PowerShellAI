# PowerShell LLM Runner

This little project lets you talk to an OpenAI-compatible API (cloud or local) and get back PowerShell commands.

You get two modes:

- **`jarvis`** → ask in English, it gets the command from the LLM, shows it, and (if it looks safe) runs it.
- **`friday`** → ask in English, it gets the command from the LLM, shows it, and copies it to your clipboard, but does **not** run it.

This is meant to be simple, portable, and usable on air-gapped / local LLM setups that expose an OpenAI-style endpoint.

---

## Files in this repo

- `jarvis1.py` — Python script that calls the LLM and prints ONLY the PowerShell command. PowerShell then executes it.
- `friday1.py` — Python script that calls the LLM and prints ONLY the PowerShell command. PowerShell does **not** execute it.
- `powershellai.ps1` — PowerShell functions (`jarvis` and `friday`) that wrap the Python scripts.

You can rename them to `jarvis.py` / `friday.py` if you prefer — just update the paths in the PowerShell file.

---

## 1. Prerequisites

- **Windows 10/11** with PowerShell
- **Python 3** installed and available on `PATH` (so running `python --version` works)
- **An OpenAI-compatible API endpoint**. This can be:
  - the real OpenAI API: `https://api.openai.com/v1`
  - a local model runner that exposes an OpenAI API, e.g. LM Studio, OpenWebUI, vLLM, text-gen with OpenAI plugin, etc.
- A (possibly dummy) API key. Many local servers just want the header to exist.

This project uses only the Python standard library (`urllib`, `json`), so you **do not** need to install the `openai` Python package.

---

## 2. Folder layout

Example layout (what you already have):

```text
C:\
 └─ AlexDev\
     └─ ps\
         └─ WorkScript\
             ├─ jarvis1.py
             ├─ friday1.py
             └─ powershellai.ps1
You can clone the repo straight into C:\AlexDev\ps\WorkScript or any folder you like — just keep the paths consistent in the PowerShell script.

3. Configure environment variables

Both Python scripts read three environment variables:

OPENAI_BASE_URL

OPENAI_API_KEY

OPENAI_MODEL

This is how you switch between cloud and local.

3.1 Using real OpenAI (cloud)

In PowerShell:

setx OPENAI_BASE_URL "https://api.openai.com/v1"
setx OPENAI_API_KEY "sk-your-real-openai-key-here"
setx OPENAI_MODEL "gpt-5-nano"


Close and reopen PowerShell so it picks up the new variables.

3.2 Using a local OpenAI-compatible server

If your local LLM is running at http://127.0.0.1:1234/v1:

setx OPENAI_BASE_URL "http://127.0.0.1:1234/v1"
setx OPENAI_API_KEY "sk-local-test"
setx OPENAI_MODEL "your-local-model-name"


Again, open a new PowerShell after this.

To find the model name on your local server, try opening http://127.0.0.1:1234/v1/models in a browser — most OpenAI-compatible servers expose that.

4. Load the PowerShell functions

The PowerShell script (powershellai.ps1) defines two functions: jarvis and friday.

You have two ways to use it:

4.1 One-off (for testing)

From the folder where the file lives:

. C:\AlexDev\ps\WorkScript\powershellai.ps1


Now in the same PowerShell window you can run:

jarvis get the current directory
friday list services that are stopped

4.2 Permanent (load on every PowerShell start)

Edit your PowerShell profile:

notepad $PROFILE


Add this line:

. C:\AlexDev\ps\WorkScript\powershellai.ps1


Save, then reload:

. $PROFILE


# PowerShell LLM Runner

This project lets you ask an OpenAI-compatible API (cloud or local) for PowerShell commands and use them right from your terminal.

You get two modes:
- `jarvis` runs the returned PowerShell after a quick safety check.
- `friday` shows the returned PowerShell and copies it to the clipboard without running it.

The scripts stay portable and work on air-gapped setups as long as an OpenAI-style endpoint is available.

---

## Files in this repo

- `jarvis1.py` prints the PowerShell command returned by the LLM; PowerShell executes it.
- `friday1.py` prints the PowerShell command; PowerShell does not execute it.
- `powershellai.ps1` defines the PowerShell functions `jarvis` and `friday` that wrap the Python scripts.

Rename the scripts if you prefer (`jarvis.py`, `friday.py`), just update the paths in `powershellai.ps1`.

---

## 1. Prerequisites

- Windows 10/11 with PowerShell
- Python 3 available on `PATH` (`python --version` should work)
- An OpenAI-compatible API endpoint such as `https://api.openai.com/v1` or a local runner (LM Studio, OpenWebUI, vLLM, etc.)
- An API key (dummy keys usually work for local servers)

The Python scripts rely only on the standard library (`urllib`, `json`); no extra packages are required.

---

## 2. Folder layout

Example layout:

```text
C:\
 └─ AlexDev\
   └─ ps\
     └─ WorkScript\
       ├─ jarvis1.py
       ├─ friday1.py
       └─ powershellai.ps1
```

Clone or copy the files to any folder you like; just keep the paths in the PowerShell script accurate.

---

## 3. Configure environment variables

Both Python scripts read:
- `OPENAI_BASE_URL`
- `OPENAI_API_KEY`
- `OPENAI_MODEL`

Use these to switch between cloud and local backends.

### 3.1 Using real OpenAI (cloud)

```powershell
setx OPENAI_BASE_URL "https://api.openai.com/v1"
setx OPENAI_API_KEY "sk-your-real-openai-key-here"
setx OPENAI_MODEL "gpt-5-nano"
```

Close and reopen PowerShell so it picks up the new variables.

### 3.2 Using a local OpenAI-compatible server

If your local server listens at `http://127.0.0.1:1234/v1`:

```powershell
setx OPENAI_BASE_URL "http://127.0.0.1:1234/v1"
setx OPENAI_API_KEY "sk-local-test"
setx OPENAI_MODEL "your-local-model-name"
```

Open a new PowerShell session afterward. Many servers list available models at `http://127.0.0.1:1234/v1/models`.

---

## 4. Load the PowerShell functions

The `powershellai.ps1` script declares `jarvis` and `friday`. Load it either temporarily or permanently.

### 4.1 One-off (for testing)

From the folder containing the script:

```powershell
. C:\AlexDev\ps\WorkScript\powershellai.ps1
```

Then run commands such as:

```powershell
jarvis get the current directory
friday list services that are stopped
```

### 4.2 Permanent (load on every PowerShell start)

Edit your PowerShell profile:

```powershell
notepad $PROFILE
```

Add this line, save, then reload the profile:

```powershell
. C:\AlexDev\ps\WorkScript\powershellai.ps1
. $PROFILE
```

New PowerShell sessions will now have `jarvis` and `friday` ready.

---

## 5. How it works

### 5.1 `jarvis`

```powershell
jarvis get the current directory
```

PowerShell invokes:

```powershell
python C:\AlexDev\ps\WorkScript\jarvis1.py get the current directory
```

`jarvis1.py` prompts the LLM to return PowerShell only. The function:
- shows the generated command
- copies it to the clipboard
- blocks a small list of risky commands
- executes it with `Invoke-Expression`

### 5.2 `friday`

```powershell
friday list services that are stopped
```

`friday1.py` retrieves the command, shows it, and copies it to the clipboard without executing it. Use this mode when you want to review commands before running them manually.
