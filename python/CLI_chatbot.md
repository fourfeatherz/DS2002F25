# CLI Chatbot on a GCP VM (Step‑by‑Step, Lightweight HF Models)

## Goal

Build a simple **terminal chatbot** you can run on a small GCP VM using a lightweight open model from Hugging Face. You can then integrate this with your API later. Step 3 will be to teach it things you want it to know. You can use this on your OWN machine and/or the Google instance.

We’ll use **llama.cpp** via the `llama-cpp-python` bindings (CPU‑friendly, easy to install) and a tiny chat‑tuned model in **GGUF** format. You’ll end with a `cli_chatbot.py` you can extend for projects.

---

## What you’ll build

- A Python CLI that:
  - Loads a small chat model locally (no API keys)
  - Keeps multi‑turn chat history
  - Streams tokens as they generate
  - Supports a configurable system prompt

---

## Prereqs (works great on low spec)

- Ubuntu 22.04/24.04 VM (e.g., e2‑standard‑2 or better)
- Python 3.10+ and `pip`
- ~2–4 GB free disk for one tiny model

> Tip: CPU only is fine for 0.5B–1.1B models.

---

## 1) SSH in & update

```bash
sudo apt update && sudo apt -y upgrade
sudo apt -y install python3-venv python3-pip git
```

---

## 2) Create a project folder & venv

```bash
mkdir -p ~/hf-cli-bot && cd ~/hf-cli-bot
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip wheel
```

---

## 3) Install llama.cpp Python bindings (this one takes a sec)

```bash
sudo apt update
sudo apt install -y build-essential cmake ninja-build

sudo apt install -y libopenblas-dev
CMAKE_ARGS="-DLLAMA_BLAS=ON -DLLAMA_BLAS_VENDOR=OpenBLAS" pip install llama-cpp-python

pip install --only-binary=:all: llama-cpp-python
```

> On most GCP Ubuntu images this installs a CPU wheel. If it tries to compile, give it a few minutes. If your VM has an NVIDIA GPU and CUDA drivers, you can later explore GPU acceleration with `pip install llama-cpp-python[cuda]` and add `n_gpu_layers>0`. We aren't using GPUs here.

---

## 4) Grab a tiny chat model (GGUF)

Pick **one** of these (both Apache‑2.0):

**Option A (very small): Qwen2.5‑0.5B‑Instruct (GGUF)**

```bash
mkdir -p models/qwen2.5-0.5b && cd models/qwen2.5-0.5b
# Small, fast quantization
wget https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf -O qwen2.5b-q4_k_m.gguf
cd ../../
```

**Option B (still small): TinyLlama‑1.1B‑Chat‑v1.0 (GGUF)**

```bash
mkdir -p models/tinyllama-1.1b && cd models/tinyllama-1.1b
wget https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf -O tinyllama-1.1b-q4_k_m.gguf
cd ../../
```

> Quantization note: `Q4_K_M` is a nice balance of speed/quality on CPUs.

---

## 5) Create the CLI app

Create `cli_chatbot.py` in your project folder with this content:

```python
#!/usr/bin/env python3
import sys
from pathlib import Path
from llama_cpp import Llama

MODEL_PATH = Path("models/qwen2.5-0.5b/qwen2.5b-q4_k_m.gguf")  # or switch to TinyLlama path

# Hyperparameters you can tweak in class
N_CTX = 4096           # context window tokens
N_THREADS = 4          # set to vCPUs on the VM
N_BATCH = 256          # token batch size

# System prompt (style/behavior)
SYSTEM_PROMPT = (
    "You are a helpful teaching assistant. Keep answers concise, add clarifying steps when appropriate."
)

print(f"Loading model: {MODEL_PATH} …", file=sys.stderr)
llm = Llama(
    model_path=str(MODEL_PATH),
    n_ctx=N_CTX,
    n_threads=N_THREADS,
    n_batch=N_BATCH,
    verbose=False,
)

history = [
    {"role": "system", "content": SYSTEM_PROMPT},
]

print("\\nCLI chatbot ready. Type 'exit' or 'quit' to leave.\\n")

while True:
    try:
        user = input("you › ").strip()
    except (EOFError, KeyboardInterrupt):
        print("\\nbye! 👋")
        break

    if user.lower() in {"exit", "quit"}:
        print("bye! 👋")
        break

    history.append({"role": "user", "content": user})

    # Stream tokens as they’re generated
    stream = llm.create_chat_completion(
        messages=history,
        stream=True,
        temperature=0.7,
        top_p=0.95,
        max_tokens=512,
    )

    print("bot › ", end="", flush=True)
    assistant_reply = []
    for chunk in stream:
        token = chunk["choices"][0]["delta"].get("content", "")
        if token:
            assistant_reply.append(token)
            print(token, end="", flush=True)
    print()  # newline after streaming

    history.append({"role": "assistant", "content": "".join(assistant_reply)})
```

Make it executable:

```bash
chmod +x cli_chatbot.py
```

---

## 6) Run it

```bash
./cli_chatbot.py
```

Try: `Explain how token sampling works in plain English.`

---

## 7) Swap models (optional)

Use TinyLlama instead of Qwen by changing `MODEL_PATH` to:

```python
MODEL_PATH = Path("models/tinyllama-1.1b/tinyllama-1.1b-q4_k_m.gguf")
```

---

## 8) Speed & quality tuning (what each knob does)

**Big picture:** you’re balancing *speed*, *memory use*, and *answer quality*. Smaller numbers usually mean faster/cheaper; larger numbers usually mean better context/quality but more RAM/VRAM.

### Threads (`N_THREADS`)

- **What it is:** How many CPU threads the model uses in parallel.
- **Effect:** Higher = faster generation until you saturate the CPU; too high can actually slow things (context switching) or compete with other processes.
- **How to choose:** Set to your VM’s vCPU count.
  ```bash
  nproc     # prints logical CPU cores
  ```
- **Typical values:** 2–8 on small/e2 machines. Start with `N_THREADS = nproc` and dial down if the VM feels sluggish.

### Context window (`N_CTX`)

- **What it is:** The maximum number of tokens (roughly words/subwords) the model can consider from prompt + history.
- **Effect:** Bigger context = the bot “remembers” longer conversations or big prompts, but uses more RAM and can be slower.
- **RAM rule of thumb:** Doubling context can noticeably increase memory use. On tiny VMs, prefer 2k over 4k.
- **Typical values:** 2048–4096 for small models on CPU VMs. If you see OOM (out‑of‑memory) errors, drop this first.

### Batch size (`N_BATCH`)

- **What it is:** How many tokens are processed per internal step.
- **Effect:** Larger can speed up throughput but increases transient RAM usage. Too large → slower or OOM.
- **Typical values:** 128–512 on CPU. If you hit OOM or things feel jittery, try 128 or 64.

### Quantization level (your GGUF file choice)

- **What it is:** A compressed weight format that trades some quality for much lower RAM and faster CPU inference.
- **Effect:** Lower‑bit = faster/smaller; higher‑bit = better quality/slower.
- **Common picks:**
  - `Q3_K_M` → fastest/smallest; quality drops more.
  - `Q4_K_M` → **great default** balance for CPU.
  - `Q5_K_M` → a bit better quality; slightly slower/bigger.
- **Tip:** If responses feel flaky, try moving up (Q4→Q5). If you’re OOM/slow, move down (Q5→Q4 or Q3).

### GPU offload (optional)

- **What it is:** Push some layers to the GPU to accelerate inference.
- **How to enable:** Install CUDA variant and set layers to offload.
  ```bash
  pip install --upgrade "llama-cpp-python[cuda]"
  ```
  In code, pass `n_gpu_layers=20` (or higher) to `Llama(...)`.
- **Effect:** More offloaded layers = faster (until VRAM fills). If you exceed VRAM, you’ll crash or slow down.
- **Rule of thumb:** Start at 10–20 layers and increase until you’re near, but not exceeding, VRAM limits.

### Sampling knobs (quality/creativity)

These don’t change memory much but affect style/consistency:

- **`temperature`**: Randomness of choices. 0.2–0.7 is concise/grounded; 0.9+ is more creative/chaotic.
- **`top_p`**: Nucleus sampling. 0.8–0.95 is common; lower = safer/more deterministic.
- **`max_tokens`**: Hard cap on generated length. Lower for speed; raise for longer explanations.

---

**Cheat sheet:**

- Low‑spec VM struggling? ↓ `N_CTX`, ↓ `N_BATCH`, pick `Q3_K_M` or `Q4_K_M`, set `N_THREADS = nproc`.
- Answers feel shallow? Try `Q5_K_M`, slightly higher `temperature` (0.7→0.8), or a better system prompt.
- Have a GPU? Use the CUDA wheel and increment `n_gpu_layers` until near VRAM limit.

---

## 9) Troubleshooting quick hits

- **Model won’t load**: path typo or insufficient RAM → try a smaller quant (`Q3_K_M`) or smaller model.
- **Weird answers**: ensure you’re using an *instruct/chat* model (not a base model).
- **Slow typing**: lower `max_tokens`, lower `N_CTX`, try a smaller quant.
- **Build errors on install**: upgrade toolchain `sudo apt install build-essential cmake` then reinstall `llama-cpp-python`.

---

## Bonus: Transformers-only variant (slower on CPU)

If you prefer sticking to standard HF Transformers, try this minimal example (ok on bigger VMs or GPUs):

```bash
pip install transformers torch --extra-index-url https://download.pytorch.org/whl/cpu
```

```python
from transformers import AutoModelForCausalLM, AutoTokenizer
import torch

model_id = "Qwen/Qwen2.5-0.5B-Instruct"

model = AutoModelForCausalLM.from_pretrained(model_id, torch_dtype=torch.float32, device_map="cpu")
tok = AutoTokenizer.from_pretrained(model_id)

history = [
    {"role": "system", "content": "You are a helpful TA."},
]

while True:
    prompt = input("you › ")
    history.append({"role": "user", "content": prompt})
    text = tok.apply_chat_template(history, tokenize=False, add_generation_prompt=True)
    input_ids = tok(text, return_tensors="pt").input_ids
    out = model.generate(input_ids, max_new_tokens=256, do_sample=True, temperature=0.7, top_p=0.95)
    reply = tok.decode(out[0][input_ids.shape[-1]:], skip_special_tokens=True)
    print("bot ›", reply)
    history.append({"role": "assistant", "content": reply})
```

---

### You’re done!

You now have a clean, CPU‑friendly CLI chatbot you can build, run, and extend on a basic GCP VM, or your own box.
