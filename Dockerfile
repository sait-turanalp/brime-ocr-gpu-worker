# RunPod Serverless GPU OCR worker (GitHub-integration ile RunPod build eder).
# Base'de CUDA 12.8 + cuDNN (torch) hazır → üstüne ORT 1.24 (CUDA-12 feed) + TRT 10.9 + gpuserve.
# Modeller + binary BUILD-time R2 CDN'den (repoya gömülü değil → İZOLASYON + küçük repo).
FROM runpod/pytorch:1.0.2-cu1281-torch280-ubuntu2404

ARG R2=https://pub-4775c8e869ad4babab985c16c87c1c2b.r2.dev

RUN pip install --break-system-packages --no-cache-dir \
      onnxruntime-gpu==1.24.4 \
      --index-url https://aiinfra.pkgs.visualstudio.com/PublicPackages/_packaging/onnxruntime-cuda-12/pypi/simple/ \
      --extra-index-url https://pypi.org/simple/ \
 && pip install --break-system-packages --no-cache-dir tensorrt==10.9.0.34 nvidia-cudnn-cu12 onnx runpod

RUN mkdir -p /models && cd /models \
 && wget -q $R2/medium/det.onnx $R2/medium/rec.onnx $R2/medium/dict.txt $R2/add_argmax.py \
 && python add_argmax.py rec.onnx rec_argmax.onnx && rm -f add_argmax.py rec.onnx
RUN wget -qO /usr/local/bin/gpuserve $R2/gpuserve && chmod +x /usr/local/bin/gpuserve

ENV ORT_DYLIB_PATH=/usr/local/lib/python3.12/dist-packages/onnxruntime/capi/libonnxruntime.so.1.24.4
ENV LD_LIBRARY_PATH=/usr/local/lib/python3.12/dist-packages/tensorrt_libs:/usr/local/lib/python3.12/dist-packages/onnxruntime/capi:/usr/local/lib/python3.12/dist-packages/nvidia/cudnn/lib:/usr/local/cuda/lib64
ENV WORKERS=1

RUN cd /models && wget -q $R2/medium/det_ctx.onnx $R2/medium/rec_argmax_ctx.onnx || echo "ctx yok"
COPY handler.py /handler.py
COPY start.sh /start.sh
CMD ["bash", "/start.sh"]
