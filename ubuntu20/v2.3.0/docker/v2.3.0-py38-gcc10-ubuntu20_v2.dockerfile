ARG BASE_IMAGE=ubuntu:20.04
ARG BUILD_IMAGE=provarepro/tensorflow:deps-py38-gcc10-ubuntu20

FROM ${BUILD_IMAGE} as builder 

USER root

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8 \
    LANGUAGE=C.UTF-8 \
    PYTHON_VERSION="3.8" \
    PYVER="38"

WORKDIR /tmp

# Install TF
ENV TF_VER="2.3.0"

ADD py38-gcc10-ubuntu20.tar.gz /tmp/.

RUN mv /tmp/py38-gcc10-ubuntu20 /tmp/tf_files && \
    python${PYTHON_VERSION} -m pip install --ignore-installed --no-cache-dir \
        /tmp/tf_files/tensorflow-${TF_VER}-cp${PYVER}-cp${PYVER}-linux_x86_64.whl

RUN mkdir -p /deps-installation/tf-cc/lib && \
    cd /deps-installation/tf-cc && \
    TF_INSTALL_PATH=`python${PYTHON_VERSION} -m pip show tensorflow | grep "Location:" | cut -d" " -f2` && \
    cp -r ${TF_INSTALL_PATH}/tensorflow/include ./ && \
    cp /tmp/tf_files/libtensorflow_cc.so.2.*.0 ./lib/ && \
    cd lib && \
    ln -s libtensorflow_cc.so.${TF_VER} libtensorflow_cc.so.2 && \
    ln -s libtensorflow_cc.so.2 libtensorflow_cc.so

ADD https://github.com/intel/mkl-dnn/releases/download/v0.21/mklml_lnx_2019.0.5.20190502.tgz /tmp

RUN tar xf /tmp/mklml_lnx_2019.0.5.20190502.tgz && \
    cp /tmp/mklml_lnx_2019.0.5.20190502/lib/libmklml_intel.so /deps-installation/tf-cc/lib/. && \
    cp /tmp/mklml_lnx_2019.0.5.20190502/lib/libiomp5.so /deps-installation/tf-cc/lib/. && \
    rm -rf /tmp/*

WORKDIR /

FROM ${BASE_IMAGE}

USER root

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8 \
    LANGUAGE=C.UTF-8 \
    PYTHON_VERSION="3.8" \
    PYVER="38"

# Intall Python
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        gpg-agent \
        build-essential \
        cmake \
        curl \
        wget \
        unzip \
        ca-certificates \
        sudo \
        software-properties-common \
        python${PYTHON_VERSION}-dev \
        python${PYTHON_VERSION}-distutils \
        libicu-dev \
        libbz2-dev \        
        liblzma-dev && \
    cd /usr/bin && \
    ln -s python${PYTHON_VERSION} python && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install GCC 10
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        gcc-10 \
        g++-10 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN update-alternatives \
        --install /usr/bin/gcc gcc /usr/bin/gcc-10 100 \
        --slave /usr/bin/g++ g++ /usr/bin/g++-10 \
        --slave /usr/bin/gcc-ar gcc-ar /usr/bin/gcc-ar-10 \
        --slave /usr/bin/gcc-nm gcc-nm /usr/bin/gcc-nm-10 \
        --slave /usr/bin/gcc-ranlib gcc-ranlib /usr/bin/gcc-ranlib-10 \
        --slave /usr/bin/gcov gcov /usr/bin/gcov-10 \
        --slave /usr/bin/gcov-dump gcov-dump /usr/bin/gcov-dump-10 \
        --slave /usr/bin/gcov-tool gcov-tool /usr/bin/gcov-tool-10 && \
    update-alternatives \
        --install /usr/bin/cpp cpp /usr/bin/cpp-10 100

RUN --mount=src=/usr/local,dst=/builder/local,from=builder \
    cp -r /builder/local/bin/pip* /usr/local/bin/. && \
    cp -r /builder/local/bin/wheel /usr/local/bin/wheel && \
    cp -r /builder/local/lib/python3.8/dist-packages/* /usr/local/lib/python3.8/dist-packages/.

RUN --mount=src=/opt,dst=/builder/opt,from=builder \
    cp -r /builder/opt/opencv /opt/opencv && \
    cp -r /builder/opt/boost /opt/boost

ENV OpenCV_DIR=/opt/opencv/lib/cmake/opencv4

COPY --from=builder /deps-installation /deps-installation

WORKDIR /
