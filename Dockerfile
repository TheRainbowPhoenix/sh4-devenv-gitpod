# FROM scratch
FROM gitpod/workspace-full-vnc

# ENV PREFIX "$HOME/opt/cross"
ENV TARGET sh4eb-elf

FROM debian:bullseye-slim AS prereqs
RUN apt-get -qq update
RUN apt-get -y install build-essential libmpfr-dev libmpc-dev libgmp-dev libpng-dev ppl-dev curl git cmake texinfo

FROM prereqs AS binutils
WORKDIR /
RUN curl -L http://ftpmirror.gnu.org/binutils/binutils-2.34.tar.bz2 | tar xj
RUN mkdir build-binutils
WORKDIR /build-binutils
RUN ../binutils-2.34/configure --target=sh4eb-nofpu-elf --prefix=$prefix  --disable-nls \
        -disable-shared --disable-multilib
RUN make -j$(nproc)
RUN make install

FROM binutils AS gcc
WORKDIR /
RUN curl -L http://ftpmirror.gnu.org/gcc/gcc-10.1.0/gcc-10.1.0.tar.xz | tar xJ
RUN mkdir build-gcc
WORKDIR /build-gcc
RUN ../gcc-10.1.0/configure --target=sh4eb-nofpu-elf --prefix=$prefix \
        --enable-languages=c,c++ \
		--with-newlib --without-headers --disable-hosted-libstdcxx \
        --disable-tls --disable-nls --disable-threads --disable-shared \
        --enable-libssp --disable-libvtv --disable-libada \
        --with-endian=big --enable-lto --with-multilib-list=m4-nofpu
RUN make -j$(nproc) inhibit_libc=true all-gcc
RUN make install-gcc

RUN make -j$(nproc) inhibit_libc=true all-target-libgcc
RUN make install-target-libgcc

FROM debian:bullseye-slim
COPY --from=gcc /usr/local /usr/local
RUN apt-get -qq update && apt-get -qqy install make libmpc3 && apt-get -qqy clean

USER root

COPY setup.sh /tmp
RUN cd /tmp && /tmp/setup.sh && rm -rf /tmp/setup.sh

# USER gitpod