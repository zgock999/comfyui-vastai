# 5090 (Compute Capability 10.0) を意識し、最新の PyTorch イメージを選択
FROM vastai/pytorch:latest

# 1. 最小限のシステムツール追加
RUN apt-get update && apt-get install -y \
    tmux rclone vim libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# 2. ComfyUI 本体と依存関係の導入
WORKDIR /workspace
RUN git clone https://github.com/comfyanonymous/ComfyUI.git && \
    cd ComfyUI && \
    pip install --no-cache-dir -r requirements.txt

# 3. SageAttention の導入
# 5090 環境（CUDA 12.x）でその場でビルドさせるのが最も確実
RUN pip install --no-cache-dir sageattention==2.2.0 --no-build-isolation --break-system-packages

# 4. Custom Nodesの導入
## Manager を pip から入れる（前回特定した最新仕様）
RUN pip3 install comfyui-manager --break-system-packages

## カスタムノードのインストール
### 一つの RUN で && を多用せず、分割するか個別に実行することで原因を特定しやすくします
RUN cd custom_nodes && \
    git clone --depth 1 https://github.com/city96/ComfyUI-GGUF.git && \
    git clone --depth 1 https://github.com/kijai/ComfyUI-KJNodes.git && \
    git clone --depth 1 https://github.com/yolain/ComfyUI-Easy-Use.git && \
    git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Impact-Pack.git && \
    git clone --depth 1 https://github.com/sylym/comfy_vid2vid comfyui-vid2vid

# 各ノードの依存関係を個別にインストール（エラーが出たノードを特定するため）
# 失敗してもビルドを止めない `--no-cache-dir` などを付けて安定させます
RUN for req in custom_nodes/*/requirements.txt; do pip3 install --break-system-packages --no-cache-dir -r "$req"; done

# 5. ディレクトリの事前作成（rclone 同期先）
RUN mkdir -p /workspace/ComfyUI/models/unet \
    && mkdir -p /workspace/ComfyUI/models/loras \
    && mkdir -p /workspace/ComfyUI/models/checkpoints

# 6. 便利エイリアスの追加
RUN echo "alias comfy='python3 /workspace/ComfyUI/main.py --listen 0.0.0.0 --use-sage-attention --fast --normalvram'" >> ~/.bashrc
