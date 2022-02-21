ARG BASE_IMAGE=ubuntu:20.04

FROM ${BASE_IMAGE}

USER root

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8 \
    LANGUAGE=C.UTF-8 \
    OPENCV_VERSION="4.4.0" \
    PYTHON_VERSION="3.8" \
    PYVER = "38"

WORKDIR /tmp

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
        python${PYTHON_VERSION}-distutils && \
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

# Intall OpenCV
RUN curl https://bootstrap.pypa.io/get-pip.py -o /get-pip.py && \
    python${PYTHON_VERSION} /get-pip.py && \
    python${PYTHON_VERSION} -m pip install --no-cache-dir \
        numpy==1.18.5 \
        cython && \
    curl -LO https://github.com/opencv/opencv/archive/${OPENCV_VERSION}.zip && \
    unzip -q ${OPENCV_VERSION}.zip && \
    rm ${OPENCV_VERSION}.zip && \
    cd /tmp/opencv-${OPENCV_VERSION} && \
    mkdir build && cd build && \
    cmake \
        -DPYTHON_EXECUTABLE=/usr/bin/python${PYTHON_VERSION} \
        -DPYTHON3_LIBRARY=/usr/lib/x86_64-linux-gnu/libpython${PYTHON_VERSION}m.so \
        -DPYTHON3_INCLUDE_DIR=/usr/include/python${PYTHON_VERSION} \
        -DCMAKE_INSTALL_PREFIX=/opt/opencv \
        .. && \
    cmake --build . && make install

ENV OpenCV_DIR=/opt/opencv/lib/cmake/opencv4

# Install Boost
RUN apt-get update && \
    apt-get install -y --no-install-recommends \        
        libicu-dev \
        libbz2-dev \        
        liblzma-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV BOOST_VERSION="1.74.0" \
    _BOOST_VERSION="1_74_0"

RUN gcc --version && \
    wget -q https://boostorg.jfrog.io/artifactory/main/release/${BOOST_VERSION}/source/boost_${_BOOST_VERSION}.tar.gz && \
    tar xf boost_${_BOOST_VERSION}.tar.gz && \
    cd boost_${_BOOST_VERSION} && \
    ./bootstrap.sh --prefix=/opt/boost/${_BOOST_VERSION} && \
    ./b2 install

# Build TF
# Download TF
ENV TF_VER="2.3.0"

# Install Bazel
RUN wget https://github.com/tensorflow/tensorflow/archive/refs/tags/v${TF_VER}.tar.gz && \
    tar xf v${TF_VER}.tar.gz && \
    BAZEL_VER=`cat tensorflow-${TF_VER}/.bazelversion` && \
    curl https://bazel.build/bazel-release.pub.gpg | apt-key add - && \
    echo "deb [arch=amd64] https://storage.googleapis.com/bazel-apt stable jdk1.8" | tee /etc/apt/sources.list.d/bazel.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        bazel-${BAZEL_VER} && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    cd /usr/bin/ && \
    ln -s bazel-${BAZEL_VER} bazel

# Build and install TF Python
RUN python${PYTHON_VERSION} -m pip install --no-cache-dir \
        keras_preprocessing && \
    cd tensorflow-${TF_VER} && \
    yes "" | python${PYTHON_VERSION} ./configure.py && \
    export BAZEL_ARGS="--config=mkl --config=opt -c opt \
                       --copt=-I/usr/include/openssl --host_copt=-I/usr/include/openssl \
                       --linkopt=-l:libssl.so.1.1 --linkopt=-l:libcrypto.so.1.1 \
                       --host_linkopt=-l:libssl.so.1.1 --host_linkopt=-l:libcrypto.so.1.1 \
                       --host_copt=-Wno-stringop-truncation" && \
    bazel build -j 2 ${BAZEL_ARGS[@]} //tensorflow/tools/pip_package:build_pip_package && \
    bazel-bin/tensorflow/tools/pip_package/build_pip_package /tmp && \
    python${PYTHON_VERSION} -m pip install --ignore-installed --no-cache-dir \
        /tmp/tensorflow-${TF_VER}-cp${PYVER}-cp${PYVER}-linux_x86_64.whl

# Build and install TF C++
RUN cd tensorflow-${TF_VER} && \
    bazel build -j 2 --config=mkl --config=opt --config=monolithic -c opt //tensorflow:libtensorflow_cc.so

RUN mkdir -p /deps-installation/tf-cc/lib && \
    cd /deps-installation/tf-cc && \
    TF_INSTALL_PATH=`python${PYTHON_VERSION} -m pip show tensorflow | grep "Location:" | cut -d" " -f2` && \
    cp -r ${TF_INSTALL_PATH}/tensorflow/include ./ && \
    cp /tmp/tensorflow-${TF_VER}/bazel-bin/tensorflow/libtensorflow_cc.so.2.*.0 ./lib/ && \
    cd lib && \
    ln -s libtensorflow_cc.so.${TF_VER} libtensorflow_cc.so.2 && \
    ln -s libtensorflow_cc.so.2 libtensorflow_cc.so

ADD https://github.com/intel/mkl-dnn/releases/download/v0.21/mklml_lnx_2019.0.5.20190502.tgz /tmp

RUN cp /tmp/mklml_lnx_2019.0.5.20190502/lib* /deps-installation/tf-cc/lib/.

