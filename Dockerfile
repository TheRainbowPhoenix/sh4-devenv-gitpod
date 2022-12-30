FROM debian:bullseye-slim as base

# ENV PREFIX "/opt/cross"

ENV PATH /opt/cross/bin:$PATH
ENV SDK_DIR /opt/cross/hollyhock-2/sdk

# TODO: maybe put the build stuff into a separate "prereq" image and publish a "clean" version without GCC source and stuff,
# but it could be helpful is some wanted to add some lib into it so dunno ...

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
# RUN rm -rf /opt/cross/binutils-build

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
# RUN rm -rf /opt/cross/gcc-build

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

# TODO: Install newlib and build it

# version=1.14.0
# prefix=~/cross/src/hollyhock-2/sdk/newlib
# jobs=`nproc 2> /dev/null || echo 1`
# wget ftp://sourceware.org/pub/newlib/newlib-${version}.tar.gz
# tar xzfv newlib-${version}.tar.gz
# mkdir newlib-${version}-build
# cd newlib-${version}-build
# export TARGET_BINS=${TARGET}
# ./newlib-${version}/configure --target="sh-elf" --prefix=$PREFIX

# I used this to fix names :
# grep -rli 'sh-elf-' * | xargs -i@ sed -i 's/sh-elf-/sh4eb-nofpu-elf-/g' @
# grep -rli 'sh4eb-nofpu-elf-cc' * | xargs -i@ sed -i 's/sh4eb-nofpu-elf-cc/sh4eb-nofpu-elf-gcc/g' @

# make -j $jobs
# make install



# ===================================================================================================================================================
# STAGE 2 : User and home
# ===================================================================================================================================================
FROM debian:bullseye-slim

ENV USERNAME="dev"
ENV SDK_DIR=/opt/cross/hollyhock-2/sdk


# COPY --from=binutils /opt/cross/ /opt/cross/
COPY --from=prereqs /usr/local /usr/local
# COPY --from=newlib /usr/local /usr/local
RUN apt-get -qq update && apt-get -qqy install make libmpc3 sudo git && apt-get -qqy clean

# Clone and make SDK
WORKDIR /opt/cross/
RUN git clone https://github.com/SnailMath/hollyhock-2.git
WORKDIR /opt/cross/hollyhock-2/sdk
RUN make -j$(nproc)

# TODO: Install doxygen and build docs?

# Also I think I got the "layer" thing : binutils is the layer you're creating => FROM <stuff> AS binutils

# TODO: Compile test app in hollihock-2/app_template
# Really good idea ! And we could do binary diff-ing with an already-compiled binary in the repo ...
# I guess I can pr both .bin and .hhk files in the repo, and chat with snailmath later ...
# Or they could be in a separate repo, with just compiled binaries
# We could ship them, and use volumes to mount the file into the docker (I did once that ...)
# COPY ./app /var/app     <= ./app is your repo directory, /var/app is the VM dir
# yeah volume seems like a great idea
# also for dev env / web server there's the "CMD" : CMD ["node", "app.js", "--host", "0.0.0.0", "--port", "80"]
# cool, that's quite useful and simple

# TODO: setup a repo into the classpaddev git org when it's nicely done. Same for that docker on docker hub
# TODO: integrate this image into base app / github actions

USER root

# Fixing some files
RUN mkdir /opt/cross/hollyhock-2/sdk/newlib/
RUN ln -s /usr/local/sh-elf/ /opt/cross/hollyhock-2/sdk/newlib/sh-elf
# Adding a sh4eb-nofpu-elf variant to sh4-elf
WORKDIR /usr/local/bin
RUN for f in sh4-elf-* ; do ln -s "$f" "sh4eb-nofpu-elf-"$(echo "$f" | cut -d'-' -f3-) ; done

COPY setup.sh /tmp

RUN useradd -rm -d /home/$USERNAME -s /bin/bash -g root -G sudo -u 1001 -p "$(openssl passwd -1 ${USERNAME})" $USERNAME
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# RUN echo ${USERNAME}:${USERNAME} | chpasswd
USER $USERNAME
WORKDIR /home/$USERNAME
RUN echo "export SDK_DIR=${SDK_DIR}" >> ~/.bashrc
# RUN cd /tmp && /tmp/setup.sh && rm -rf /tmp/setup.sh

# USER gitpod
