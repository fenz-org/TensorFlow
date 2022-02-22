ARG BASE_IMAGE=provarepro/tensorflow:deps-py38-gcc10-ubuntu20

FROM ${BASE_IMAGE}

USER root

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8 \
    LANGUAGE=C.UTF-8 \
    OPENCV_VERSION="4.4.0" \
    PYTHON_VERSION="3.8" \
    PYVER="38"

WORKDIR /tmp

# Install TF
ENV TF_VER="2.3.0"

## Install Bazel
#RUN wget https://github.com/tensorflow/tensorflow/archive/refs/tags/v${TF_VER}.tar.gz && \
#    tar xf v${TF_VER}.tar.gz && \
#    BAZEL_VER=`cat tensorflow-${TF_VER}/.bazelversion` && \
#    curl https://bazel.build/bazel-release.pub.gpg | apt-key add - && \
#    echo "deb [arch=amd64] https://storage.googleapis.com/bazel-apt stable jdk1.8" | tee /etc/apt/sources.list.d/bazel.list && \
#    apt-get update && \
#    apt-get install -y --no-install-recommends \
#        bazel-${BAZEL_VER} && \
#    apt-get clean && \
#    rm -rf /var/lib/apt/lists/* && \
#    cd /usr/bin/ && \
#    ln -s bazel-${BAZEL_VER} bazel
#
## Build and install TF Python
#RUN python${PYTHON_VERSION} -m pip install --no-cache-dir \
#        keras_preprocessing && \
#    cd tensorflow-${TF_VER} && \
#    python${PYTHON_VERSION} ./configure.py
#
#    yes "" | ./configure
#
#RUN cd tensorflow-${TF_VER} && \
#    export BAZEL_ARGS="--config=mkl --config=opt -c opt \
#                       --copt=-I/usr/include/openssl --host_copt=-I/usr/include/openssl \
#                       --linkopt=-l:libssl.so.1.1 --linkopt=-l:libcrypto.so.1.1 \
#                       --host_linkopt=-l:libssl.so.1.1 --host_linkopt=-l:libcrypto.so.1.1 \
#                       --host_copt=-Wno-stringop-truncation" && \
#    bazel build -j 2 ${BAZEL_ARGS[@]} //tensorflow/tools/pip_package:build_pip_package && \
#    bazel-bin/tensorflow/tools/pip_package/build_pip_package /tmp && \
#    python${PYTHON_VERSION} -m pip install --ignore-installed --no-cache-dir \
#        /tmp/tensorflow-${TF_VER}-cp${PYVER}-cp${PYVER}-linux_x86_64.whl && \
#    bazel build -j 2 --config=mkl --config=opt --config=monolithic -c opt //tensorflow:libtensorflow_cc.so && \
#    mkdir -p /deps-installation/tf-cc/lib && \
#    cd /deps-installation/tf-cc && \
#    TF_INSTALL_PATH=`python${PYTHON_VERSION} -m pip show tensorflow | grep "Location:" | cut -d" " -f2` && \
#    cp -r ${TF_INSTALL_PATH}/tensorflow/include ./ && \
#    cp /tmp/tensorflow-${TF_VER}/bazel-bin/tensorflow/libtensorflow_cc.so.2.*.0 ./lib/ && \
#    rm -rf /tmp/tensorflow* && \
#    cd lib && \
#    ln -s libtensorflow_cc.so.${TF_VER} libtensorflow_cc.so.2 && \
#    ln -s libtensorflow_cc.so.2 libtensorflow_cc.so && \
#    rm -rf /root/.cache

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
    cp /tmp/mklml_lnx_2019.0.5.20190502/lib/* /deps-installation/tf-cc/lib/. && \
    rm -rf /tmp/*

WORKDIR /
