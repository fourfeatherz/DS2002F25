# Local Chatbot API using FastAPI and `llama.cpp`

## 1. Overview

This project demonstrates how to take a lightweight local language model—originally run as a command-line chatbot—and make it accessible as a simple **API** using **FastAPI**.
The model runs entirely on your own machine (or VM), without any remote dependencies or API keys.

The API exposes an endpoint that accepts user messages and returns the model’s generated reply.
This approach lets you integrate your chatbot into other services, websites, or applications.

---

## 2. Background

The original CLI chatbot ran interactively in a terminal.
That version worked well for experimentation but wasn’t accessible from other programs.

By wrapping the same logic inside a FastAPI app, we allow network requests (HTTP POSTs) to feed prompts into the model and receive text completions in response.
Nothing about the underlying model changes—the difference is simply that FastAPI now handles input and output rather than the user typing directly at the terminal.

---

## 3. System Requirements

* **Operating System:** Ubuntu 22.04 or 24.04
* **Python:** 3.10 or newer
* **Hardware:** At least 4 GB of RAM (an `e2-standard-2` or larger GCP VM works well)
* **Network:** Internet access required the first time to download model files from Hugging Face

> If your VM has only 1 GB RAM, inference may still work with smaller quantized models, but performance will be slow.

---

## 4. Setup Procedure

### Step 1 – System Preparation

```bash
sudo apt update && sudo apt -y upgrade
sudo apt install -y python3-venv python3-pip git build-essential cmake ninja-build libopenblas-dev
```

### Step 2 – Create a Project Environment

```bash
mkdir -p ~/hf-cli-bot && cd ~/hf-cli-bot
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip wheel
```

### Step 3 – Install Dependencies

Key libraries:

* `llama-cpp-python` – Python bindings for `llama.cpp`, used for local inference
* `huggingface_hub` – handles model downloads and caching
* `fastapi` – provides the API framework
* `uvicorn` – lightweight ASGI server that runs the FastAPI app

Install them:

```bash
CMAKE_ARGS="-DLLAMA_BLAS=ON -DLLAMA_BLAS_VENDOR=OpenBLAS" pip install llama-cpp-python
pip install huggingface_hub fastapi uvicorn
```

---

## 5. Create the API Application

Create a file named **`api_chatbot.py`** in your project folder and paste the following code:

```python
#!/usr/bin/env python3
from fastapi import FastAPI
from pydantic import BaseModel
from llama_cpp import Llama
from huggingface_hub import hf_hub_download
from pathlib import Path

# Model selection
MODEL_REPO = "Qwen/Qwen2.5-0.5B-Instruct-GGUF"
MODEL_FILE = "qwen2.5-0.5b-instruct-q4_k_m.gguf"

print(f"Downloading or locating model {MODEL_REPO}...")
model_path = hf_hub_download(repo_id=MODEL_REPO, filename=MODEL_FILE, local_dir="models")

# Model configuration
N_CTX, N_THREADS, N_BATCH = 4096, 4, 256
SYSTEM_PROMPT = "You are a helpful assistant. Provide clear, concise, and accurate answers."

print("Loading model into memory...")
llm = Llama(
    model_path=str(model_path),
    n_ctx=N_CTX,
    n_threads=N_THREADS,
    n_batch=N_BATCH,
    verbose=False,
)

# Initialize conversation history
history = [{"role": "system", "content": SYSTEM_PROMPT}]

# FastAPI application
app = FastAPI(title="Local Chatbot API", version="1.0")

class ChatRequest(BaseModel):
    user_input: str

@app.post("/chat")
def chat(req: ChatRequest):
    """
    Accepts a JSON payload with one field, 'user_input',
    and returns the model's textual reply.
    """
    history.append({"role": "user", "content": req.user_input})

    stream = llm.create_chat_completion(
        messages=history,
        stream=True,
        temperature=0.7,
        top_p=0.95,
        max_tokens=512,
    )

    tokens = []
    for chunk in stream:
        token = chunk["choices"][0]["delta"].get("content", "")
        if token:
            tokens.append(token)

    reply = "".join(tokens)
    history.append({"role": "assistant", "content": reply})
    return {"reply": reply}

@app.get("/")
def root():
    return {"status": "ok", "message": "Chatbot API is running."}
```

### Discussion of Key Sections

1. **Model Loading**
   The script automatically downloads the GGUF model from Hugging Face on first run and caches it locally.
   The variable `N_THREADS` controls CPU parallelism, and `N_CTX` sets the context window size.

2. **FastAPI Application**

   * The `/chat` endpoint expects a JSON body with a single key, `user_input`.
   * It appends the input to the conversation history, generates a reply, and returns that reply as JSON.
   * The `/` endpoint provides a simple health check.

3. **Persistence of History**
   The `history` list keeps the conversation context in memory for the current session.
   Restarting the process resets the conversation context.

---

## 6. Running the Server

Start the application using **uvicorn**:

```bash
uvicorn api_chatbot:app --host 0.0.0.0 --port 8000
```

`0.0.0.0` binds to all network interfaces so external clients (within your firewall rules) can reach it.
If you only need local access, use `--host 127.0.0.1`.

When you see:

```
Uvicorn running on http://0.0.0.0:8000
```

the service is running.

---

## 7. Testing the API

### Using curl

```bash
curl -X POST "http://<VM_IP>:8000/chat" \
  -H "Content-Type: application/json" \
  -d '{"user_input": "Explain quantization in plain English."}'
```

### Using Python

```python
import requests
response = requests.post("http://<VM_IP>:8000/chat", json={"user_input": "What is token sampling?"})
print(response.json()["reply"])
```

---

## 8. How It Works Internally

When a POST request arrives at `/chat`:

1. FastAPI validates input using the Pydantic `ChatRequest` model.
2. The user message is appended to the conversation history.
3. The `llama_cpp` model streams tokens from the GGUF model.
4. Tokens are concatenated into a complete string.
5. The reply is returned as JSON.

All inference happens locally. The model never leaves your machine.

---

## 9. Extending the Service

This API can serve as the foundation for:

* A browser-based interface written in React or Flask + Tailwind
* Integration into a command center dashboard
* Use as a local reasoning or retrieval endpoint
* Experimentation with different models, sampling parameters, or prompts

Possible extensions include:

* **Streaming responses** using FastAPI’s `StreamingResponse`
* **CORS support** for web-based clients
* **Persistent storage** (save history in SQLite or a JSON file)
* **Authentication** for external access

---

## 10. Summary

This API turns your local `llama.cpp` chatbot into a reusable, network-accessible service.
Key design principles:

* Runs entirely on the local CPU—no remote API calls or costs.
* The model downloads once and is cached.
* The interface is simple JSON over HTTP.

You can scale up by switching to larger models (e.g., TinyLlama 1.1B Chat or Qwen 1.8B) by adjusting the `MODEL_REPO` and `MODEL_FILE` values.

This project bridges **interactive local inference** with **programmatic AI services**, providing a strong foundation for experimentation and practical deployment.
