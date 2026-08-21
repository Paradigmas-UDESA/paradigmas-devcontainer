FROM mcr.microsoft.com/devcontainers/base:noble

# Toolchain, debugging, testing and GUI dependencies for the Paradigmas de
# Programacion (UDESA) C++ course. Everything a student needs is baked in here
# so that per-activity devcontainer.json files only ever reference this image
# by tag -- no apt-get, no feature installs, no source builds on the
# student's machine.
#
# Base is Ubuntu 24.04 (noble) specifically because its apt repos ship
# libsfml-dev 2.6.x (the API TP-Hive targets) and prebuilt libgtest-dev
# libraries. Do not bump this to a newer Ubuntu release without re-checking
# both of those -- 26.04 is known to ship SFML 3, which is API-incompatible.

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        # Toolchain
        build-essential \
        make \
        cmake \
        ccache \
        git \
        pkg-config \
        # Debugging
        gdb \
        valgrind \
        # Testing (googletest/googlemock; noble ships prebuilt .a/.so, not
        # just headers+CMakeLists -- verify with `ls /usr/lib/*/libgtest*`)
        libgtest-dev \
        libgmock-dev \
        # GUI: SFML 2.6 plus the Mesa software rasterizer. SFML opens an
        # OpenGL context even for 2D drawing; without libgl1-mesa-dri the
        # desktop-lite feature's X server has no renderer to hand it and
        # sf::RenderWindow fails to initialize.
        libsfml-dev \
        libgl1-mesa-dri \
        libglu1-mesa \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV CXX=g++ \
    CC=gcc \
    CCACHE_DIR=/home/vscode/.ccache \
    PATH=/usr/lib/ccache:$PATH

# Base image already creates the non-root `vscode` user; UID/GID mapping to
# the host user is handled by the Dev Containers extension at runtime
# (updateRemoteUserUID), not here.
USER vscode
