# syntax=docker/dockerfile:1.7
# Fedora ROCm dev image that builds TheRock and installs /opt/rocm from the produced tarball

ARG FEDORA_VER=42

# Base toolchain/deps
FROM registry.fedoraproject.org/fedora-toolbox:${FEDORA_VER} AS builddeps
ARG FEDORA_VER

######## Python and distro Packages #######
RUN --mount=type=cache,id=f${FEDORA_VER},target=/var/cache/dnf \
    dnf5 install -y python python-devel \
      '@development-tools' clang gfortran \
      autoconf libtool m4 pkgconf-pkg-config \
      patchelf vim-enhanced git-lfs automake perl \
      libglvnd-devel numactl-devel \
      libpng-devel libjpeg-turbo-devel libwebp-devel

######## Pip Packages ########
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/bin/
RUN uv pip install --system \
      CppHeaderParser==2.7.4 meson==1.7.0 tomli==2.2.1 PyYAML==6.0.2

######## CCache ########
WORKDIR /install-ccache
COPY dockerfiles/install_ccache.sh ./
RUN ./install_ccache.sh "4.9"
WORKDIR /
RUN rm -rf /install-ccache

######## CMake ########
WORKDIR /install-cmake
ENV CMAKE_VERSION="3.25.2"
COPY dockerfiles/install_cmake.sh ./
RUN ./install_cmake.sh "${CMAKE_VERSION}"
ENV PATH="/usr/local/therock-tools/bin:${PATH}"
RUN which cmake && cmake --version
WORKDIR /
RUN rm -rf /install-cmake

######## Ninja ########
WORKDIR /install-ninja
ENV NINJA_VERSION="1.12.1"
COPY dockerfiles/install_ninja.sh ./
RUN ./install_ninja.sh "${NINJA_VERSION}"
RUN echo 'Ninja install successful'
WORKDIR /
RUN rm -rf /install-ninja

######## GoogleTest ########
WORKDIR /install-googletest
ENV GOOGLE_TEST_VERSION="1.16.0"
COPY dockerfiles/install_googletest.sh ./
RUN ./install_googletest.sh "${GOOGLE_TEST_VERSION}"
WORKDIR /
RUN rm -rf /install-googletest

# Build TheRock portable ROCm
FROM builddeps AS build
ARG FEDORA_VER

######## Git safety ########
RUN git config --global --add safe.directory '*'

######## therock-prep ########
RUN --mount=type=cache,id=pytorch-f${FEDORA_VER},target=/therock \
    mkdir -p /therock/src /therock/output

######## therock-build ########
ENV AMDGPU_TARGETS="gfx1100;gfx1151"
ENV THEROCK_INTERACTIVE=1
RUN --mount=type=cache,id=pytorch-f${FEDORA_VER},target=/therock \
    --mount=type=bind,target=/therock/src,rw \
    /therock/src/build_tools/detail/linux_portable_build_in_container.sh \
      -DTHEROCK_AMDGPU_FAMILIES="${AMDGPU_TARGETS}" \
      -DTHEROCK_AMDGPU_DIST_BUNDLE_NAME=rocm-dillflix \
      -DTHEROCK_VERBOSE=off \
      -DTHEROCK_ENABLE_RCCL=off \
      -DBUILD_TESTING=off \
      -DTHEROCK_BUNDLE_SYSDEPS=ON \
    && cmake --build /therock/output/build --target therock-archives

######## Create tarball(s) ########
RUN --mount=type=cache,id=pytorch-f${FEDORA_VER},target=/therock \
    tar -C /therock/output/build/dist/rocm \
      -cJf /opt/therock-${AMDGPU_TARGETS}-$(date +'%Y%m%d').tar.xz . && \
    cp /therock/output/build/artifacts/*.tar.xz /

# Final dev image with ROCm installed
FROM builddeps AS rocm_dev
ARG FEDORA_VER

COPY --from=build /opt/therock-*.tar.xz /opt

RUN mkdir -p /opt/rocm && \
    tar -C /opt/rocm -xJf /opt/therock-*.tar.xz && \
    rm -f /opt/*.tar.xz

# Linker paths + PATH
RUN printf '/opt/rocm/lib\n/opt/rocm/lib/rocm_sysdeps/lib\n' > /etc/ld.so.conf.d/rocm.conf && \
    ldconfig -v
RUN printf "export PATH=/opt/rocm/bin:\$PATH\n" > /etc/profile.d/rocm.sh
