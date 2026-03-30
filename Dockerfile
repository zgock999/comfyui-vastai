# 5090 (Compute Capability 10.0) を意識し、最新の PyTorch イメージを選択
FROM rocker/cuda:cuda13.0-py3.12

# 1. システムツールの追加（build-essential と python3-dev を追加）
RUN sudo apt-get update && sudo apt-get install -y \
    tmux rclone vim libgl1 libglib2.0-0 \
    build-essential python3-dev \
    cuda-toolkit-13-1 


ENV PIP_BREAK_SYSTEM_PACKAGES=1

# 1.5 ビルド用 Python パッケージを先に更新（このイメージは導入済みなのでスキップ）
#RUN pip3 install --no-cache-dir setuptools wheel

# 2. ComfyUI 本体と依存関係の導入(このイメージは/root/が作業場所)
WORKDIR /root
RUN git clone https://github.com/comfyanonymous/ComfyUI.git && \
    cd ComfyUI && \
    pip3 install --no-cache-dir -r requirements.txt


# 3. SageAttention の導入
# pipを用いたインストールはエラーになるため、公式の指定通りsetup.pyでインストール
RUN cd /root && git clone https://github.com/thu-ml/SageAttention.git && \
    cd SageAttention && python setup.py install

# 4. Custom Nodesの導入
## Manager を pip から入れる（前回特定した最新仕様）
RUN pip3 install  --no-cache-dir comfyui-manager

## カスタムノードのインストール
### 一つの RUN で && を多用せず、分割するか個別に実行することで原因を特定しやすくします
RUN cd /root/ComfyUI/custom_nodes && \
    git clone --depth 1 https://github.com/city96/ComfyUI-GGUF.git && \
    git clone --depth 1 https://github.com/kijai/ComfyUI-KJNodes.git && \
    git clone --depth 1 https://github.com/yolain/ComfyUI-Easy-Use.git && \
    git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Impact-Pack.git && \
    git clone --depth 1 https://github.com/sylym/comfy_vid2vid comfyui-vid2vid

# 各ノードの依存関係を個別にインストール（エラーが出たノードを特定するため）
# 失敗してもビルドを止めない `--no-cache-dir` などを付けて安定させます
RUN for req in /root/ComfyUI/custom_nodes/*/requirements.txt; do pip3 install --no-cache-dir -r "$req"; done

# 5. ディレクトリの事前作成（rclone 同期先/このイメージでは素直に/root/ComfyUI/modelsにディレクトリが作られるので省略）

# 6. 便利エイリアスの追加
RUN echo "alias comfy='python3 /root/ComfyUI/main.py --listen 0.0.0.0 --use-sage-attention --fast --normalvram'" >> ~/.bashrc
