"""RunPod serverless handler — ince kabuk: işi localhost gpuserve worker'larına iletir.
Ağır iş gpuserve'de (Rust+TRT). N worker (WORKERS env) → round-robin, concurrency_modifier=N
→ RunPod tek worker'a N eşzamanlı iş yollar → 2 GPU-süreci paralel (ölçülü ~1.3× throughput).
input: {"image_b64": ...} → {"lines":[...], "ms":...}."""
import asyncio
import base64
import itertools
import os
import time
import urllib.request

import runpod

N = int(os.environ.get("WORKERS", "2"))
PORTS = [8000 + i for i in range(N)]
_rr = itertools.cycle(PORTS)


def _post(port, img):
    req = urllib.request.Request(f"http://127.0.0.1:{port}/ocr", data=img,
                                 headers={"Content-Type": "application/octet-stream"})
    with urllib.request.urlopen(req, timeout=120) as r:
        import json
        return json.loads(r.read())


def _wait_ready(timeout=240):
    t0 = time.time()
    while time.time() - t0 < timeout:
        try:
            urllib.request.urlopen(f"http://127.0.0.1:{PORTS[0]}/health", timeout=2)
            return
        except Exception:
            time.sleep(1)


_wait_ready()


async def handler(job):
    img = base64.b64decode(job["input"]["image_b64"])
    port = next(_rr)                        # round-robin → boş worker'a dağıt
    return await asyncio.to_thread(_post, port, img)  # bloklamayan: eşzamanlı işler paralel


# concurrency_modifier: bu worker'a aynı anda N iş yolla (N GPU-sürecini doldur)
runpod.serverless.start({"handler": handler, "concurrency_modifier": lambda _cur: N})
