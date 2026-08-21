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

# desktop-lite's Xtigervnc defaults to 16-bit color depth
# (VNC_RESOLUTION=...x16 in /usr/local/share/desktop-init.sh, only applied
# when the var is unset). At depth 16 there is no GLXFBConfig matching
# SFML's default context request, so sf::RenderWindow fails outright
# (BadValue on GLXCreateContext) -- confirmed by reproducing and then
# fixing this exact failure against the built image. 24-bit depth has a
# matching FBConfig and SFML opens/draws/displays correctly.
ENV VNC_RESOLUTION=1440x768x24

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
