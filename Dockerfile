# 5090 (Compute Capability 10.0) を意識し、最新の PyTorch イメージを選択
FROM rocker/cuda:cuda13.0-py3.12

USER root

# 1. システムツールの追加（build-essential と python3-dev を追加）
RUN apt-get update && apt-get install -y \
    tmux git rclone vim libgl1 libglib2.0-0 \
    build-essential python3-dev \
    cuda-toolkit-12-8 


ENV PIP_BREAK_SYSTEM_PACKAGES=1

# 1.5 ビルド用 Python パッケージを先に更新（このイメージは導入済みなのでスキップ）
#RUN pip3 install --no-cache-dir setuptools wheel

# 2. ComfyUI 本体と依存関係の導入
WORKDIR /workspace
RUN git clone https://github.com/comfyanonymous/ComfyUI.git && \
    cd /workspace/ComfyUI && \
    # ビルドを高速化しエラーを防ぐために ninja を追加
    pip3 install --no-cache-dir ninja && \
    # 2. 残りの依存関係をインストール
    pip3 install --no-cache-dir -r requirements.txt

# 3. SageAttention の導入
RUN git clone https://github.com/thu-ml/SageAttention.git && \
    cd SageAttention && \
    # 環境変数をインラインで渡してビルド
    CUDA_HOME=/usr/local/cuda-12.8 \
    TORCH_CUDA_ARCH_LIST="8.6 8.9 10.0" \
    FORCE_CUDA=1 \
    python3 setup.py install


WORKDIR /workspace/ComfyUI/custom_nodes

# ネットワークエラー対策のため、1つずつ個別に実行し、キャッシュを活用する
RUN git clone --depth 1 https://github.com/city96/ComfyUI-GGUF.git
RUN git clone --depth 1 https://github.com/kijai/ComfyUI-KJNodes.git
RUN git clone --depth 1 https://github.com/yolain/ComfyUI-Easy-Use.git
RUN git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Impact-Pack.git
RUN git clone --depth 1 https://github.com/sylym/comfy_vid2vid comfyui-vid2vid

# 5. 各ノードの依存関係をインストール
# requirements.txt が存在する場合のみ実行されるように記述
RUN for req in */requirements.txt; do pip3 install --no-cache-dir -r "$req"; done

# 5. ディレクトリの事前作成（rclone 同期先/このイメージでは素直に/workspace/ComfyUI/modelsにディレクトリが作られるので省略）

# 6. 便利エイリアスの追加
RUN echo "alias comfy='python3 /workspace/ComfyUI/main.py --listen 0.0.0.0 --use-sage-attention --fast --normalvram'" >> ~/.bashrc
