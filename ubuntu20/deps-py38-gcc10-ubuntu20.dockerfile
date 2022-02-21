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
    PYVER="38"

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

RUN wget -q https://boostorg.jfrog.io/artifactory/main/release/${BOOST_VERSION}/source/boost_${_BOOST_VERSION}.tar.gz && \
    tar xf boost_${_BOOST_VERSION}.tar.gz && \
    cd boost_${_BOOST_VERSION} && \
    ./bootstrap.sh \
        --prefix=/opt/boost/${_BOOST_VERSION} \
        --with-libraries=system \
        --with-libraries=filesystem && \
    ./b2 \
        --with-system \
        --with-filesystem \
        install

