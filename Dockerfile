FROM mcr.microsoft.com/devcontainers/base:noble

# Toolchain, debugging and testing dependencies for the Paradigmas de
# Programacion (UDESA) C++ course. Everything a student needs is baked in here
# so that per-activity devcontainer.json files only ever reference this image
# by tag -- no apt-get, no feature installs, no source builds on the
# student's machine.
#
# Base is Ubuntu 24.04 (noble) specifically because its apt repos ship
# prebuilt libgtest-dev libraries. Do not bump this to a newer Ubuntu release
# without re-checking that.
#
# No SFML and no VNC desktop since 2026a.2: GUIs are web pages served from
# the container and drawn by the host's browser (TP2: python3 gui/serve.py).
# Activities that still need SFML stay on the 2026a tag.

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        # Toolchain
        build-essential \
        make \
        cmake \
        ccache \
        git \
        pkg-config \
        curl \
        ca-certificates \
        # Debugging
        gdb \
        valgrind \
        # Testing (googletest/googlemock; noble ships prebuilt .a/.so, not
        # just headers+CMakeLists -- verify with `ls /usr/lib/*/libgtest*`)
        libgtest-dev \
        libgmock-dev \
        # Boost (header-only): Boost.Math root finders for TP2's engines.
        libboost-dev \
        # GUIs: a small http.server in the container, the page in the
        # host's browser. The base image happens to ship python3; say so.
        python3 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV CXX=g++ \
    CC=gcc \
    CCACHE_DIR=/home/vscode/.ccache \
    PATH=/usr/lib/ccache:$PATH

# Pre-create CCACHE_DIR owned by vscode *before* it becomes a volume mount
# point. The shared ccache volume (mounted here by every activity repo's
# devcontainer.json) gets its initial ownership from whatever exists at
# this path in the image on first creation -- if nothing exists here,
# Docker creates the mount point as root, and the non-root vscode user
# then gets "ccache: error: Permission denied" on every compile. This
# only covers volumes created fresh from this image; the
# postStartCommand chown in template/devcontainer.json re-fixes ownership
# on every start too, since Docker won't retroactively fix a
# volume that was already created root-owned by an older image.
RUN mkdir -p /home/vscode/.ccache && chown -R vscode:vscode /home/vscode/.ccache

# Base image already creates the non-root `vscode` user; UID/GID mapping to
# the host user is handled by the Dev Containers extension at runtime
# (updateRemoteUserUID), not here.
USER vscode
