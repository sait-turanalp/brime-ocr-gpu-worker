"""RunPod handler — tek + BATCH. Batch: {images:[b64,...]} tek RunPod isteğinde
localhost gpuserve'e döngüyle → serverless vergisi (dispatch/kuyruk/cold) bir kez amorti."""
import asyncio, base64, itertools, json, os, time, urllib.request
import runpod

N = int(os.environ.get("WORKERS", "1"))
PORTS = [8000 + i for i in range(N)]
_rr = itertools.cycle(PORTS)

def _post(port, img):
    req = urllib.request.Request(f"http://127.0.0.1:{port}/ocr", data=img,
                                 headers={"Content-Type": "application/octet-stream"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read())

def _wait_ready(timeout=240):
    t0 = time.time()
    while time.time() - t0 < timeout:
        try:
            urllib.request.urlopen(f"http://127.0.0.1:{PORTS[0]}/health", timeout=2); return
        except Exception:
            time.sleep(1)
_wait_ready()

async def handler(job):
    inp = job["input"]
    if isinstance(inp.get("images"), list):          # BATCH — tek istek, sunucu döngüsü
        out = []
        for b64 in inp["images"]:
            img = base64.b64decode(b64)
            out.append(await asyncio.to_thread(_post, PORTS[0], img))
        return {"results": out}
    img = base64.b64decode(inp["image_b64"])          # tek görsel
    return await asyncio.to_thread(_post, next(_rr), img)

runpod.serverless.start({"handler": handler, "concurrency_modifier": lambda _c: N})
