# NotebookLM CL — Quick Start

## 1. Get credentials from your browser

Open **notebooklm.google.com** in Chrome (Safari also works). Open DevTools
(`⌘⌥I`), go to the **Network** tab.

Click around the NotebookLM UI (or reload) to generate traffic, then find any
request to `batchexecute` in the list. Click it.

### What you need to copy

| Value | Where to look | CL flag |
|---|---|---|
| **Session ID** | **URL** → `f.sid=` parameter | `--session` |
| **CSRF token** | **Payload** tab → `at=` field (starts with `AF1_QpN-`) | `--csrf` |
| **Cookie header** | **Request Headers** → `Cookie:` (entire value) | `--cookie` |

### Example request

```
URL:
  https://notebooklm.google.com/_/batchexecute?rpcids=...&f.sid=AAH2QCz1X-abcdef...&hl=en&rt=c
                                                       ^^^^^^^^^^^^^^^^
                                                       THIS is --session

Payload:
  f.req=...&at=AF1_QpN-POzpI8aNdS2U...&
              ^^^^^^^^^^^^^^^^^^^^^^^^
              THIS is --csrf

Request Headers:
  Cookie: SID=g.a123...; __Secure-1PSIDTS=sidts-...; HSID=Aa...; ...
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
          THIS is --cookie (optional — only needed for file uploads)
```

### Minimum required cookies in `--cookie`

If you do pass `--cookie`, Google requires at minimum:

- **`SID`** and **`__Secure-1PSIDTS`** (Tier 1 — hard requirement)
- **`OSID`**, **or** both **`APISID`** + **`SAPISID`** (Tier 2 — secondary binding)

But the easiest approach: copy the **entire** `Cookie:` header value.
It naturally contains all of these.

---

## 2. Install & login

**Option A — Paste cURL (easiest):**
```bash
# Right-click any batchexecute request in DevTools → Copy → Copy as cURL (bash)
# Then paste into the terminal and press Ctrl+D:
./notebooklm login --curl
```

**Option B — Manual flags:**
```bash
./notebooklm login \
  --csrf "AF1_QpN-..." \
  --session "AAH2QCz1X-..." \
  --cookie "SID=g.a123...; __Secure-1PSIDTS=sidts-...; ..."
```

**`--cookie` is optional.**  
Without it, all RPC operations work (list, generate, download, delete).
You only need `--cookie` for `add-file-source` (uploading local files).

---

## 3. Commands

```bash
# Notebooks
./notebooklm notebooks                          # List all notebooks
./notebooklm create-notebook "My Research"      # Create new notebook

# Sources
./notebooklm sources <notebook-id>              # List sources in a notebook
./notebooklm sources <notebook-id> --json       # Machine-readable
./notebooklm add-url <notebook-id> <url>        # Add a URL source
./notebooklm delete-source <notebook-id> <src-id>

# Metadata
./notebooklm metadata <notebook-id>             # Overview + source summaries
./notebooklm metadata <notebook-id> --json

# Artifacts
./notebooklm artifacts <notebook-id>            # List all artifacts
./notebooklm artifacts <notebook-id> --type audio
./notebooklm artifacts <notebook-id> --type report --json
./notebooklm delete-artifact <notebook-id> <artifact-id>

# Generate
./notebooklm generate audio <notebook-id>
./notebooklm generate report <notebook-id> --format briefing_doc
./notebooklm generate report <notebook-id> --format custom --prompt "Analyze..."
./notebooklm generate quiz <notebook-id>
./notebooklm generate flashcards <notebook-id>
./notebooklm generate video <notebook-id>
./notebooklm generate cinematic <notebook-id>
./notebooklm generate infographic <notebook-id>
./notebooklm generate slide-deck <notebook-id>
./notebooklm generate data-table <notebook-id>
./notebooklm generate mind-map <notebook-id>

# Optional generate flags
#   --source-ids id1,id2    (comma-separated source IDs)
#   --language en           (language code, default: en)
#   --instructions "..."    (custom instructions for the AI)

# Poll for completion
./notebooklm wait <notebook-id> <task-id>
./notebooklm wait <notebook-id> <task-id> --timeout 600

# Download
./notebooklm download audio <notebook-id> output.wav
./notebooklm download video <notebook-id> output.mp4
./notebooklm download report <notebook-id> output.md
./notebooklm download data-table <notebook-id> output.csv
./notebooklm download slide-deck <notebook-id> output.pdf
./notebooklm download quiz <notebook-id> output.md
./notebooklm download flashcards <notebook-id> output.md
./notebooklm download infographic <notebook-id> output.png
./notebooklm download mind-map <notebook-id> output.json

# Download flags
#   --id <artifact-id>      (pick specific artifact, default: newest completed)
#   --format pdf|pptx        (slide-deck only)
#   --format markdown|json   (quiz/flashcards only)

# Report suggestions
./notebooklm suggest <notebook-id>

# Delete
./notebooklm delete-artifact <notebook-id> <artifact-id>
./notebooklm delete-source <notebook-id> <source-id>

# Status
./notebooklm whoami
```

---

## 4. Workflow example

```bash
# Start
./notebooklm login --csrf "AF1..." --session "AAH..." --cookie "SID=..."

# Create a notebook
./notebooklm create-notebook "Q4 Earnings Analysis"
# → Created: nb_abc123
#    Title: Q4 Earnings Analysis

# Add sources
./notebooklm add-url nb_abc123 https://example.com/earnings-report.pdf
./notebooklm sources nb_abc123
# → src_001  earnings-report.pdf  [pdf]

# Generate an audio overview
./notebooklm generate audio nb_abc123
# → Status: in_progress
#    Task ID: art_xyz789

# Wait for it (typical: 2-5 min for audio)
./notebooklm wait nb_abc123 art_xyz789
# → Status: completed
#    URL: https://...

# Download it
./notebooklm download audio nb_abc123 earnings-podcast.wav
# → ✅ Downloaded to earnings-podcast.wav

# Generate + download a briefing doc too
./notebooklm generate report nb_abc123 --format briefing_doc
# → Task ID: art_def456
./notebooklm wait nb_abc123 art_def456
./notebooklm download report nb_abc123 briefing.md
```

---

## 5. Credential storage

Credentials are saved to `~/.notebooklm-cl/auth.json`. To switch accounts:

```bash
./notebooklm login --csrf "..." --session "..." --cookie "..."
# Overwrites the previous credentials
```

To log out:

```bash
rm ~/.notebooklm-cl/auth.json
```

---

## 6. Build from source

```bash
cd /path/to/notebooklm-cl
./build.sh
# → notebooklm (14MB, macOS arm64 binary)
```

Requires SBCL 2.6.4+. The binary is self-contained — no runtime dependencies.

---

## 7. Known limitations

- **`--help` with dashes**: SBCL eats `--help` before our code sees it.
  Use `help` (no dashes) or pass `-- help` (with a `--` separator).
- **File uploads**: Not yet wired in CLI. The library has `add-file-source`,
  just needs a CLI wrapper.
- **No auto-refresh**: Cookies expire eventually. Re-login when calls start
  returning 401/403 errors.
