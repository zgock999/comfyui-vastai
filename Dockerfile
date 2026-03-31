# 5090 (Blackwell) 最適化イメージ
FROM rocker/cuda:cuda13.0-py3.12
USER root

# 1. パスを 13.0 に固定（ここが極めて重要）
# 1. パス固定（シンボリックリンク /usr/local/cuda を活用）
ENV CUDA_HOME=/usr/local/cuda
ENV PATH=${CUDA_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}
ENV PIP_BREAK_SYSTEM_PACKAGES=1

# 2. システムツール (13.0 で統一)
RUN apt-get update && apt-get install -y \
    git tmux rclone vim libgl1 libglib2.0-0 \
    build-essential python3-dev ninja-build \
    cuda-toolkit-13-1 \
    && rm -rf /var/lib/apt/lists/*
# ※ 13.0 で統一するため、前回の /compat 削除は不要（あっても無害）です

WORKDIR /workspace

# 3. ComfyUI 本体と PyTorch (cu130) の導入
# ホストの 570系ドライバと完全に一致させる
RUN pip3 install --no-cache-dir ninja

RUN git clone https://github.com/comfyanonymous/ComfyUI.git && \
    cd ComfyUI && \
    pip3 install --no-cache-dir --force-reinstall \
    torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu130 && \
    pip3 install --no-cache-dir -r requirements.txt

# 4. SageAttention (13.0 コンパイラで 8.6/8.9/10.0 用をビルド)
RUN git clone https://github.com/thu-ml/SageAttention.git && \
    cd SageAttention && \
    TORCH_CUDA_ARCH_LIST="8.6 8.9 10.0" FORCE_CUDA=1 python3 setup.py install

# 5. Custom Nodes の導入 (ネットワークエラー対策で分割)
WORKDIR /workspace/ComfyUI/custom_nodes
RUN git clone --depth 1 https://github.com/city96/ComfyUI-GGUF.git
RUN git clone --depth 1 https://github.com/kijai/ComfyUI-KJNodes.git
RUN git clone --depth 1 https://github.com/yolain/ComfyUI-Easy-Use.git
RUN git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Impact-Pack.git
RUN git clone --depth 1 https://github.com/sylym/comfy_vid2vid comfyui-vid2vid

# 6. 各カスタムノードの依存関係をインストール
RUN for req in */requirements.txt; do pip3 install --no-cache-dir -r "$req"; done

# 7. Manager を pip から導入
RUN pip3 install --no-cache-dir comfyui-manager

# 8. 便利エイリアスの追加
RUN echo "alias comfy='python3 /workspace/ComfyUI/main.py --listen 0.0.0.0 --use-sage-attention --fast --normalvram'" >> ~/.bashrc
