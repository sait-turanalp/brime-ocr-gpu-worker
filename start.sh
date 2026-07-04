#!/usr/bin/env bash
# N gpuserve HTTP worker'ı başlat (8000..8000+N-1). İlk worker engine'i kurar (network-volume
# cache); sonrakiler aynı cache'ten hızlı yükler (build-race yok). Sonra RunPod handler.
set -e
CACHE=${TRT_CACHE:-/runpod-volume/trtcache}   # network volume → engine cache kalıcı
WORKERS=${WORKERS:-2}
mkdir -p "$CACHE"

start_worker() { /usr/local/bin/gpuserve --serve --port "$1" --models /models --cache "$CACHE" --batch 16 & }
wait_health() { until curl -sf "http://127.0.0.1:$1/health" >/dev/null 2>&1; do sleep 0.5; done; }

# worker 0: engine'i kur/yükle (cold start'ta build burada olur)
start_worker 8000; wait_health 8000
# kalan worker'lar: aynı cache → hızlı
for i in $(seq 1 $((WORKERS-1))); do start_worker $((8000+i)); done
for i in $(seq 1 $((WORKERS-1))); do wait_health $((8000+i)); done

exec python3 -u /handler.py
