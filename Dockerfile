# 5090 (Compute Capability 10.0) を意識した最新環境
FROM rocker/cuda:cuda13.0-py3.12
USER root

# 1. 環境変数の固定
ENV CUDA_HOME=/usr/local/cuda-12.8
ENV PATH=${CUDA_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}
ENV PIP_BREAK_SYSTEM_PACKAGES=1

# 2. システムツール (12.8で統一) と Error 804 回避
RUN apt-get update && apt-get install -y \
    git tmux rclone vim libgl1 libglib2.0-0 \
    build-essential python3-dev ninja-build \
    cuda-toolkit-12-8 \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /usr/local/cuda-12.8/compat

WORKDIR /workspace

# 3. ComfyUI 本体と PyTorch (cu126) の導入
# ここで本体のクローンと基本依存関係をすべて終わらせます
RUN git clone https://github.com/comfyanonymous/ComfyUI.git && \
    cd ComfyUI && \
    pip3 install --no-cache-dir --force-reinstall \
    torch torchvision torchaudio ninja --index-url https://download.pytorch.org/whl/cu126 && \
    pip3 install --no-cache-dir -r requirements.txt

# 4. SageAttention (12.8コンパイラで 8.6/8.9/10.0用をビルド)
RUN git clone https://github.com/thu-ml/SageAttention.git && \
    cd SageAttention && \
    TORCH_CUDA_ARCH_LIST="8.6 8.9 10.0" FORCE_CUDA=1 python3 setup.py install

# 5. Custom Nodes の導入
WORKDIR /workspace/ComfyUI/custom_nodes
# ネットワークエラー対策で分割。失敗してもここからリトライ可能
RUN git clone --depth 1 https://github.com/city96/ComfyUI-GGUF.git
RUN git clone --depth 1 https://github.com/kijai/ComfyUI-KJNodes.git
RUN git clone --depth 1 https://github.com/yolain/ComfyUI-Easy-Use.git
RUN git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Impact-Pack.git
RUN git clone --depth 1 https://github.com/sylym/comfy_vid2vid comfyui-vid2vid

# 6. 各カスタムノードの依存関係をインストール
RUN for req in */requirements.txt; do pip3 install --no-cache-dir -r "$req"; done

# 7. Manager を pip から導入（最新仕様）
RUN pip3 install --no-cache-dir comfyui-manager

# 8. 便利エイリアスの追加
RUN echo "alias comfy='python3 /workspace/ComfyUI/main.py --listen 0.0.0.0 --use-sage-attention --fast --normalvram'" >> ~/.bashrc
