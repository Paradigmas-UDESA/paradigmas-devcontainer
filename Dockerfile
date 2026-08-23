FROM mcr.microsoft.com/devcontainers/base:noble

# Toolchain, debugging, testing and GUI dependencies for the Paradigmas de
# Programacion (UDESA) C++ course. Everything a student needs is baked in here
# so that per-activity devcontainer.json files only ever reference this image
# by tag -- no apt-get, no feature installs, no source builds on the
# student's machine.
#
# Base is Ubuntu 24.04 (noble) specifically because its apt repos ship
# prebuilt libgtest-dev libraries and the 2.6.x-era SFML dependency stack
# (the API TP-Hive targets). Do not bump this to a newer Ubuntu release
# without re-checking both of those -- 26.04 is known to ship SFML 3, which
# is API-incompatible.

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
        # SFML build dependencies. SFML itself is NOT installed from apt --
        # see the source build below -- but every library it links against
        # is, and the -dev packages have to stay in the image so student
        # code can link -lsfml-graphics et al.
        libx11-dev \
        libxrandr-dev \
        libxcursor-dev \
        libxi-dev \
        libudev-dev \
        libfreetype-dev \
        libgl1-mesa-dev \
        libflac-dev \
        libogg-dev \
        libvorbis-dev \
        libopenal-dev \
        # GUI: the Mesa software rasterizer. SFML opens an OpenGL context
        # even for 2D drawing; without libgl1-mesa-dri the desktop-lite
        # feature's X server has no renderer to hand it and sf::RenderWindow
        # fails to initialize.
        libgl1-mesa-dri \
        libglu1-mesa \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# --- SFML, built from source with one bug fix backported -----------------
#
# Ubuntu's libsfml-dev (2.6.1) cannot reliably open a window on the
# desktop-lite VNC display. Roughly half of all runs die with:
#
#   Failed to get GLXFBConfig which corresponds to the window's visual
#   X Error of failed request:  BadValue ... X_GLXCreateContext
#
# Root cause is a genuine SFML 2.6 bug, in
# src/SFML/Window/Unix/GlxContext.cpp, GlxContext::selectBestVisual(): it
# loops over every visual XGetVisualInfo() reports and scores it, but the
# attribute variables it fills (`int doubleBuffer; int red, green, ...`)
# are left UNINITIALIZED, and glXGetConfig() does not write *value when it
# fails. For a visual that has no matching GLXFBConfig it fails on every
# attribute, so SFML scores that visual from stack garbage -- and when the
# garbage happens to score best, SFML creates the window with a visual GLX
# cannot make a context for, which is the BadValue above. Confirmed with
# valgrind ("Conditional jump depends on uninitialised value(s)" inside
# libsfml-window, gone after this patch) and by repeat-run trials: stock
# 2.6.1 failed 9/15 and 13/20 runs of TP-Hive, the patched build 0/30 --
# and 0/20 for a bare sf::RenderWindow on this image as built by CI.
#
# Xtigervnc reports 20 such non-GLX visuals out of 100, and -- unlike, say,
# Xvfb -- reports one of them FIRST, so the very first loop iteration reads
# true garbage. That is why the failure is a coin flip rather than
# deterministic, and why it looked "fixed" by unrelated changes before.
#
# Upstream fixed this in SFML 3 (all locals initialized to 0) but never
# backported it to 2.6.x -- 2.6.2, the last 2.6 release, still has the bug.
# Since the course is pinned to the 2.6 API, build 2.6.2 here and apply the
# SFML 3 initialization. Everything else about the library is stock.
#
# Deliberately placed BEFORE the ccache ENV block below: with
# /usr/lib/ccache on PATH and CCACHE_DIR set, this root-run build would
# populate /home/vscode/.ccache as root and every student compile would
# then fail with "ccache: error: Permission denied".
ARG SFML_VERSION=2.6.2
RUN curl -fsSL "https://github.com/SFML/SFML/archive/refs/tags/${SFML_VERSION}.tar.gz" -o /tmp/sfml.tar.gz \
    && tar -xzf /tmp/sfml.tar.gz -C /tmp \
    && cd "/tmp/SFML-${SFML_VERSION}" \
    && sed -i \
        -e 's/^\( *\)int doubleBuffer;$/\1int doubleBuffer = 0;/' \
        -e 's/^\( *\)int red, green, blue, alpha, depth, stencil, multiSampling, samples, sRgb;$/\1int red = 0, green = 0, blue = 0, alpha = 0, depth = 0, stencil = 0, multiSampling = 0, samples = 0, sRgb = 0;/' \
        -e 's/^\( *\)int depth, stencil, multiSampling, samples, sRgb;$/\1int depth = 0, stencil = 0, multiSampling = 0, samples = 0, sRgb = 0;/' \
        src/SFML/Window/Unix/GlxContext.cpp \
    # Fail the build rather than silently shipping an unpatched SFML if a
    # future SFML_VERSION bump reformats these declarations.
    && grep -q 'int doubleBuffer = 0;' src/SFML/Window/Unix/GlxContext.cpp \
    && grep -q 'int red = 0, green = 0,' src/SFML/Window/Unix/GlxContext.cpp \
    && grep -q 'int depth = 0, stencil = 0,' src/SFML/Window/Unix/GlxContext.cpp \
    && cmake -S . -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=ON \
        -DSFML_BUILD_EXAMPLES=OFF \
        -DSFML_BUILD_DOC=OFF \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
    && cmake --build build -j"$(nproc)" \
    && cmake --install build \
    && ldconfig \
    && rm -rf "/tmp/SFML-${SFML_VERSION}" /tmp/sfml.tar.gz

ENV CXX=g++ \
    CC=gcc \
    CCACHE_DIR=/home/vscode/.ccache \
    PATH=/usr/lib/ccache:$PATH

# desktop-lite's Xtigervnc defaults to 16-bit color depth
# (VNC_RESOLUTION=...x16 in /usr/local/share/desktop-init.sh, only applied
# when the var is unset). 24-bit is what the GUI activities are drawn for
# and what students' screenshots should look like, so pin it here.
#
# NOTE: this is a display-quality setting, not a correctness one. An
# earlier revision of this file claimed 24-bit depth fixed the
# "Failed to get GLXFBConfig" crash; it does not -- that crash is the SFML
# bug patched above, it reproduces at depth 24, and with the patch in place
# TP-Hive runs 15/15 clean at depth 16 as well.
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
