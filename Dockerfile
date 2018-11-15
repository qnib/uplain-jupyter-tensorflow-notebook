ARG FROM_IMG_REGISTRY=docker.io
ARG FROM_IMG_REPO=qnib
ARG FROM_IMG_NAME=uplain-jupyter-cuda-notebook
ARG FROM_IMG_TAG=2018-11-14.2
ARG FROM_IMG_HASH=''
FROM ${FROM_IMG_REGISTRY}/${FROM_IMG_REPO}/${FROM_IMG_NAME}:${FROM_IMG_TAG}${DOCKER_IMG_HASH}

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        build-essential \
        curl \
        libfreetype6-dev \
        libpng12-dev \
        libzmq3-dev \
        pkg-config \
        python \
        python-dev \
        rsync \
        software-properties-common \
        unzip \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

  RUN curl -O https://bootstrap.pypa.io/get-pip.py \
   && python get-pip.py \
   && rm get-pip.py

 RUN pip --no-cache-dir install \
         Pillow \
         h5py \
         ipykernel \
         jupyter \
         matplotlib \
         numpy \
         pandas \
         scipy \
         sklearn \
 && python -m ipykernel.kernelspec

 # Install TensorFlow GPU version.
 RUN pip --no-cache-dir install tensorflow-gpu
RUN mkdir -p /root/.jupyter/ \
 && wget -qO /root/.jupyter/jupyter_notebook_config.py https://github.com/tensorflow/tensorflow/raw/r1.4/tensorflow/tools/docker/jupyter_notebook_config.py

 # Set up Bazel.

 # Running bazel inside a `docker build` command causes trouble, cf:
 #   https://github.com/bazelbuild/bazel/issues/134
 # The easiest solution is to set up a bazelrc file forcing --batch.
 RUN echo "startup --batch" >>/etc/bazel.bazelrc
 # Similarly, we need to workaround sandboxing issues:
 #   https://github.com/bazelbuild/bazel/issues/418
 RUN echo "build --spawn_strategy=standalone --genrule_strategy=standalone" \
     >>/etc/bazel.bazelrc
 # Install the most recent bazel release.

# Download and build TensorFlow.
RUN apt-get update \
  && apt-get install -y --no-install-recommends git-core
RUN git clone https://github.com/tensorflow/tensorflow.git
RUN cd tensorflow \
  && git checkout r1.10

# Configure the build for our CUDA configuration.
ENV CI_BUILD_PYTHON python
ENV LD_LIBRARY_PATH /usr/local/cuda/extras/CUPTI/lib64:$LD_LIBRARY_PATH
ENV TF_NEED_CUDA 1
ENV TF_CUDA_COMPUTE_CAPABILITIES=3.0,3.5,5.2,6.0,6.1

RUN apt-get install -y --allow-unauthenticated cuda-cublas-dev-9-2
ENV BAZEL_VERSION 0.19.1
WORKDIR /
RUN mkdir /bazel && \
    cd /bazel && \
    curl -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/57.0.2987.133 Safari/537.36" -fSsL -O https://github.com/bazelbuild/bazel/releases/download/$BAZEL_VERSION/bazel-$BAZEL_VERSION-installer-linux-x86_64.sh && \
    curl -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/57.0.2987.133 Safari/537.36" -fSsL -o /bazel/LICENSE.txt https://raw.githubusercontent.com/bazelbuild/bazel/master/LICENSE && \
    chmod +x bazel-*.sh && \
    ./bazel-$BAZEL_VERSION-installer-linux-x86_64.sh && \
    cd / && \
    rm -f /bazel/bazel-$BAZEL_VERSION-installer-linux-x86_64.sh
