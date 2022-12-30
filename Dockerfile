FROM debian:bullseye-slim as base

# ENV PREFIX "/opt/cross"

ENV PATH /opt/cross/bin:$PATH
ENV SDK_DIR /opt/cross/hollyhock-2/sdk

RUN apt-get -qq update
RUN apt-get -y install curl git cmake

# ===================================================================================================================================================
# STAGE 1 : Build stuff
# ===================================================================================================================================================
FROM debian:bullseye-slim AS prereqs

ENV PREFIX="/usr/local"
ENV TARGET=sh4-elf

RUN apt-get -qq update
RUN apt-get -y install build-essential libmpfr-dev libmpc-dev libgmp-dev libpng-dev ppl-dev curl git cmake texinfo

# FROM prereqs AS binutils
RUN mkdir /opt/cross/
WORKDIR /opt/cross/

RUN curl -L http://ftpmirror.gnu.org/binutils/binutils-2.34.tar.bz2 | tar xj
RUN mkdir binutils-build
WORKDIR /opt/cross/binutils-build
# --prefix=$prefix
RUN ../binutils-2.34/configure --target=${TARGET} --prefix=${PREFIX} --disable-nls \
        -disable-shared --disable-multilib
RUN make -j$(nproc)
RUN make install

# cleaning up
RUN rm -rf /opt/cross/binutils-2.34

# FROM binutils AS gcc
WORKDIR /opt/cross/
RUN curl -L http://ftpmirror.gnu.org/gcc/gcc-10.1.0/gcc-10.1.0.tar.xz | tar xJ
RUN mkdir /opt/cross/gcc-build
WORKDIR /opt/cross/gcc-build
# --prefix=$prefix
RUN ../gcc-10.1.0/configure --target=${TARGET} --prefix=${PREFIX} \ 
        --enable-languages=c,c++ \
		--with-newlib --without-headers --disable-hosted-libstdcxx \
        --disable-tls --disable-nls --disable-threads --disable-shared \
        --enable-libssp --disable-libvtv --disable-libada \
        --with-endian=big --enable-lto --with-multilib-list=m4-nofpu
RUN make -j$(nproc) inhibit_libc=true all-gcc
RUN make install-gcc

RUN make -j$(nproc) inhibit_libc=true all-target-libgcc
RUN make install-target-libgcc

# cleaning up
RUN rm -rf /opt/cross/gcc-10.1.0

# Clone and make NewLib

ENV NEWLIB_VER "1.14.0"
ENV TARGET_BINS ${TARGET}

# FROM gcc AS newlib
WORKDIR /opt/cross/
RUN curl http://sourceware.org/pub/newlib/newlib-${NEWLIB_VER}.tar.gz -o newlib-${NEWLIB_VER}.tar.gz 
RUN tar xzf newlib-${NEWLIB_VER}.tar.gz
RUN rm -rf newlib-${NEWLIB_VER}.tar.gz

RUN mkdir build-newlib
WORKDIR /opt/cross/newlib-build
# CC_FOR_TARGET=${TARGET_BINS}-gcc AS_FOR_TARGET=${TARGET_BINS}-as LD_FOR_TARGET=${TARGET_BINS}-ld AR_FOR_TARGET=${TARGET_BINS}-ar RANLIB_FOR_TARGET=${TARGET_BINS}-ranlib
RUN ../newlib-${NEWLIB_VER}/configure --target="sh-elf" --prefix=$PREFIX
RUN grep -rli 'sh-elf-' * | xargs -i@ sed -i 's/sh-elf-/sh4-elf-/g' @
RUN grep -rli 'sh4-elf-cc' * | xargs -i@ sed -i 's/sh4-elf-cc/sh4-elf-gcc/g' @
RUN make -j$(nproc) all
RUN make install

# ===================================================================================================================================================
# STAGE 2 : User and home
# ===================================================================================================================================================
FROM debian:bullseye-slim

ENV USERNAME="dev"
ENV SDK_DIR=/opt/cross/hollyhock-2/sdk

COPY --from=prereqs /usr/local /usr/local
RUN apt-get -qq update && apt-get -qqy install make libmpc3 sudo git && apt-get -qqy clean

# Clone and make SDK
WORKDIR /opt/cross/
RUN git clone https://github.com/SnailMath/hollyhock-2.git
WORKDIR /opt/cross/hollyhock-2/sdk
RUN make -j$(nproc)

# TODO: Install doxygen and build docs?

# TODO: Compile test app in hollihock-2/app_template

# TODO: setup a repo into the classpaddev git org when it's nicely done. Same for that docker on docker hub
# TODO: integrate this image into base app / github actions

USER root

# Fixing some files
RUN mkdir /opt/cross/hollyhock-2/sdk/newlib/
RUN ln -s /usr/local/sh-elf/ /opt/cross/hollyhock-2/sdk/newlib/sh-elf

COPY setup.sh /tmp

RUN useradd -rm -d /home/$USERNAME -s /bin/bash -g root -G sudo -u 1001 -p "$(openssl passwd -1 ${USERNAME})" $USERNAME
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# RUN echo ${USERNAME}:${USERNAME} | chpasswd
USER $USERNAME
WORKDIR /home/$USERNAME
# RUN cd /tmp && /tmp/setup.sh && rm -rf /tmp/setup.sh
