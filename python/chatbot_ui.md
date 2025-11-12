# Local Chatbot Web App (FastAPI + llama.cpp) — Step‑by‑Step Guide

This README shows you, carefully and methodically, how to turn a local GGUF model (via `llama.cpp`) into a **browser‑based chatbot** with a **FastAPI** backend. We will:

* Serve a clean, responsive web page.
* Stream tokens to the browser in real time using **Server‑Sent Events (SSE)**.
* Shut down **gracefully** so the process leaves **no zombie children**.

If you follow the steps in order, you’ll have a working web app you can adapt for your own projects.

---

## 0) What you’ll build

* A FastAPI service that loads a small, CPU‑friendly chat model (e.g., **Qwen2.5‑0.5B‑Instruct‑GGUF**).
* An `/` route that serves a simple, professional HTML front‑end.
* A `/chat/stream` endpoint that **streams** tokens back to the browser as they are generated.
* Proper signal handling and FastAPI shutdown hooks to free resources cleanly.

---

## 1) Prerequisites

* Ubuntu 22.04/24.04 (works locally or on a GCP VM)
* Python **3.10+**
* 4 GB RAM or more recommended (e.g., `e2-standard-2` on GCP)
* Basic terminal/SSH comfort

> **Why 4 GB?** Tiny quantized models load and run more smoothly with a few gigabytes of RAM. You can try lower specs, but you may encounter out‑of‑memory errors or very slow inference.

---

## 2) Prepare your environment

```bash
sudo apt update && sudo apt -y upgrade
sudo apt install -y python3-venv python3-pip git build-essential cmake ninja-build libopenblas-dev

mkdir -p ~/hf-chatbot && cd ~/hf-chatbot
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip wheel
```

---

## 3) Install Python libraries

We’ll use:

* **`llama-cpp-python`** to run the local GGUF model.
* **`huggingface_hub`** to auto‑download the model weights.
* **`fastapi`** and **`uvicorn`** for the web service.
* **`jinja2`** to render our HTML template.

```bash
CMAKE_ARGS="-DLLAMA_BLAS=ON -DLLAMA_BLAS_VENDOR=OpenBLAS" pip install llama-cpp-python
pip install fastapi uvicorn huggingface_hub jinja2
```

> If `llama-cpp-python` attempts a local build, give it some time; the OpenBLAS‑enabled wheel improves CPU performance.

---

## 4) Project layout

Create the folders like this:

```
hf-chatbot/
├── .venv/
├── models/
├── templates/
│   └── index.html   ← we’ll create this
└── web_chatbot.py   ← we’ll create this
```

---

## 5) Backend application (`web_chatbot.py`)

Create a file named **`web_chatbot.py`** with the following content. Read through the comments; they’re meant to teach...it's good for you :-)

```python
#!/usr/bin/env python3
from fastapi import FastAPI, Request
from fastapi.responses import StreamingResponse, HTMLResponse
from fastapi.templating import Jinja2Templates
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from huggingface_hub import hf_hub_download
from llama_cpp import Llama
import asyncio
import signal
import sys

# --------------------
# Model setup
# --------------------
# A compact, chat-tuned GGUF model. Adjust to taste:
MODEL_REPO = "Qwen/Qwen2.5-0.5B-Instruct-GGUF"
MODEL_FILE = "qwen2.5-0.5b-instruct-q4_k_m.gguf"

# Auto-download on first run; cache thereafter.
model_path = hf_hub_download(repo_id=MODEL_REPO, filename=MODEL_FILE, local_dir="models")

# Keep config conservative for small VMs; raise as resources allow.
llm = Llama(model_path=str(model_path), n_ctx=2048, n_threads=4, verbose=False)
SYSTEM_PROMPT = "You are a calm, knowledgeable assistant. Write clear, concise answers."
history = [{"role": "system", "content": SYSTEM_PROMPT}]

# --------------------
# FastAPI app
# --------------------
app = FastAPI(title="Local Chatbot Web App", version="1.0")
templates = Jinja2Templates(directory="templates")
app.mount("/static", StaticFiles(directory="static"), name="static")  # optional

class ChatRequest(BaseModel):
    user_input: str

@app.get("/", response_class=HTMLResponse)
def index(request: Request):
    """Serve the chat UI."""
    return templates.TemplateResponse("index.html", {"request": request})

@app.post("/chat/stream")
async def chat_stream(req: ChatRequest):
    """Stream tokens to the browser using Server-Sent Events (SSE)."""
    history.append({"role": "user", "content": req.user_input})

    # llama.cpp streaming generator (not async). We wrap it in an async generator.
    stream = llm.create_chat_completion(
        messages=history,
        stream=True,
        temperature=0.7,
        top_p=0.95,
        max_tokens=512,
    )

    async def token_generator():
        reply_parts = []
        for chunk in stream:
            token = chunk["choices"][0]["delta"].get("content", "")
            if token:
                reply_parts.append(token)
                # SSE format requires 'data: <payload>\n\n'
                yield f"data: {token}\n\n"
                # Yielding control briefly keeps the event loop responsive
                await asyncio.sleep(0.001)
        full_reply = "".join(reply_parts)
        history.append({"role": "assistant", "content": full_reply})
        yield "data: [END]\n\n"

    return StreamingResponse(token_generator(), media_type="text/event-stream")

# --------------------
# Graceful shutdown (no zombies)
# --------------------
@app.on_event("shutdown")
def shutdown_event():
    """Release resources and flush IO on server stop."""
    try:
        # Explicitly delete model object so worker threads/handles are closed.
        global llm
        del llm
    except Exception as e:
        print(f"Issue releasing model: {e}")
    sys.stdout.flush()
    sys.stderr.flush()
    print("Server stopped gracefully.")

# Ensure SIGINT/SIGTERM lead to clean exit under systemd/Docker as well.
def _handle_exit(*_):
    sys.exit(0)

signal.signal(signal.SIGTERM, _handle_exit)
signal.signal(signal.SIGINT, _handle_exit)
```

### Why this works

* **SSE** is a simple, one‑way stream from server → browser. It’s perfect for token‑by‑token output without WebSockets.
* The **shutdown handler** and **signal hooks** ensure that when the process stops, the model object is destroyed and buffers are flushed—preventing orphaned threads.

---

## 6) Front‑end template (`templates/index.html`)

Create `templates/index.html` with a professional, minimal UI. It uses only standard CSS for broad compatibility.

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Local Chatbot</title>
  <style>
    :root {
      --bg: #f3f4f6;      /* light gray */
      --card: #ffffff;    /* white */
      --border: #e5e7eb;  /* gray-200 */
      --brand: #2563eb;   /* blue-600 */
      --brand-dark: #1d4ed8; /* blue-700 */
      --bot: #16a34a;     /* green-600 */
      --text: #111827;    /* gray-900 */
    }
    html, body { height: 100%; }
    body {
      margin: 0; background: var(--bg); color: var(--text);
      font-family: system-ui, -apple-system, Segoe UI, Roboto, Ubuntu, Cantarell, Noto Sans, Arial, "Apple Color Emoji", "Segoe UI Emoji";
      display: grid; place-items: center;
    }
    .container {
      width: min(92vw, 820px);
      background: var(--card);
      border: 1px solid var(--border);
      border-radius: 12px; box-shadow: 0 2px 10px rgba(0,0,0,0.06);
      padding: 18px 18px 14px;
      display: grid; gap: 12px;
    }
    h2 { margin: 4px 0 8px; font-weight: 650; letter-spacing: 0.2px; }
    .log {
      border: 1px solid var(--border); border-radius: 10px; padding: 12px;
      height: 56vh; overflow: auto; background: #fff;
    }
    .msg { margin: 8px 0; line-height: 1.45; }
    .user { font-weight: 600; color: var(--brand); }
    .bot { font-weight: 600; color: var(--bot); }
    .controls { display: grid; grid-template-columns: 1fr auto; gap: 8px; }
    input[type="text"] {
      border: 1px solid var(--border); border-radius: 10px; padding: 10px 12px; font-size: 1rem;
    }
    button {
      border: 1px solid var(--brand); background: var(--brand); color: #fff;
      border-radius: 10px; padding: 10px 16px; font-size: 1rem; cursor: pointer;
    }
    button:hover { background: var(--brand-dark); border-color: var(--brand-dark); }
  </style>
</head>
<body>
  <div class="container">
    <h2>Local Chatbot</h2>
    <div id="log" class="log"></div>
    <div class="controls">
      <input id="userInput" type="text" placeholder="Type a message and press Send…" />
      <button id="sendBtn">Send</button>
    </div>
  </div>

  <script>
    const log = document.getElementById('log');
    const input = document.getElementById('userInput');
    const sendBtn = document.getElementById('sendBtn');

    function appendLine(cls, who, text) {
      const div = document.createElement('div');
      div.className = 'msg ' + cls;
      div.innerHTML = `<span class="${cls}">${who}:</span> ${text}`;
      log.appendChild(div);
      log.scrollTop = log.scrollHeight;
    }

    async function sendMessage() {
      const text = input.value.trim();
      if (!text) return;
      appendLine('user', 'You', text);
      input.value = '';

      // Prepare a placeholder for the bot's streaming message
      const botLine = document.createElement('div');
      botLine.className = 'msg bot';
      botLine.innerHTML = '<span class="bot">Bot:</span> ';
      log.appendChild(botLine);

      // POST to /chat/stream and read SSE
      const resp = await fetch('/chat/stream', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ user_input: text })
      });

      const reader = resp.body.getReader();
      const decoder = new TextDecoder();
      let buffer = '';

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });
        let parts = buffer.split('\n\n');
        buffer = parts.pop();
        for (const part of parts) {
          if (part.startsWith('data: ')) {
            const payload = part.slice(6);
            if (payload === '[END]') {
              // done
            } else {
              botLine.innerHTML += payload;
              log.scrollTop = log.scrollHeight;
            }
          }
        }
      }
    }

    sendBtn.addEventListener('click', sendMessage);
    input.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') sendMessage();
    });
  </script>
</body>
</html>
```

### A quick tour of the front‑end

* We append your message immediately to keep the UI snappy.
* We create a dedicated “bot line” and **append tokens live** as they arrive.
* The scroll position follows the conversation so you never lose the latest output.

---

## 7) Run the app

From your project folder:

```bash
uvicorn web_chatbot:app --host 0.0.0.0 --port 8000
```

Open your browser to:

```
http://<VM_IP>:8000
```

Type a message and watch the reply arrive **token by token**.

> If you access this over the Internet, make sure your firewall allows TCP/8000 and that you understand the security notes below.

---

## 8) How the streaming works (conceptual)

When you POST to `/chat/stream`, the server:

1. Adds your message to an in‑memory `history` list (including a fixed system prompt).
2. Calls `llama_cpp` with `stream=True`, which yields chunks as tokens become available.
3. Wraps those chunks into **SSE events** (`data: <token>\n\n`) and sends them to the browser.
4. When finished, it sends a sentinel `data: [END]` so the client knows the turn is complete.

The browser consumes the HTTP response **incrementally**, updating the DOM as events arrive—
no WebSockets, no polling, just one long‑lived response.

---

## 9) Configuration knobs (where to tune)

In `web_chatbot.py`:

* `n_ctx` — The context window (tokens of prompt + history). Start at 2048; increase if you have RAM.
* `n_threads` — Parallel CPU threads. Set to your vCPU count for speed.
* `temperature`, `top_p`, `max_tokens` — Sampling controls for style vs. determinism and output length.
* `MODEL_REPO`, `MODEL_FILE` — Switch to different GGUF models as needed.

In `index.html` you can change the palette and layout without any build tools.

---

## 10) Networking & security notes

* By default, the app listens on all interfaces (`0.0.0.0`). If this is **not** meant for public use, bind to `127.0.0.1` or restrict with a firewall.
* For a public deployment, add **authentication** (API keys, OAuth, or a simple header token) and run behind a reverse proxy (e.g., Nginx) with HTTPS.
* Avoid exposing raw model endpoints to the Internet without rate limiting or auth.

---

## 11) Troubleshooting

* **Model won’t load / OOM:** Try a smaller quant (e.g., `q3`), lower `n_ctx`, or a smaller model family.
* **Very slow typing:** Lower `max_tokens`, reduce `n_ctx`, or increase `n_threads` up to your vCPU count.
* **No streaming in browser:** Check the Network tab—SSE uses one long HTTP response. Proxies that buffer responses can interfere.
* **Zombie processes on stop:** The shutdown handler plus SIGTERM/SIGINT hooks in `web_chatbot.py` are designed to exit cleanly. If you embed this in another process manager, ensure it sends SIGTERM and waits for exit.

---

## 12) Where to go next

* Add **CORS** if a separate front‑end will call this API.
* Add a `/reset` route to clear the in‑memory history.
* Store logs in SQLite for persistence.
* When you upgrade hardware, try larger models or longer contexts.

You now have a minimal—but well‑behaved—chatbot web app that you can bend to your will: classroom demos, internal tools, or a foundation for something much bigger.
