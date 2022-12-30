FROM debian:bullseye-slim

ENV PREFIX "/opt/cross"
ENV TARGET sh4eb-elf
ENV USERNAME "dev"

ENV PATH /opt/cross/bin:$PATH
ENV SDK_DIR /opt/cross/hollyhock-2/sdk

# TODO: maybe put the build stuff into a separate "prereq" image and publish a "clean" version without GCC source and stuff,
# but it could be helpful is some wanted to add some lib into it so dunno ...

RUN apt-get -qq update
RUN apt-get -y install curl git cmake

# FROM debian:bullseye-slim AS prereqs
RUN apt-get -qq update
RUN apt-get -y install build-essential libmpfr-dev libmpc-dev libgmp-dev libpng-dev ppl-dev curl git cmake texinfo

# FROM prereqs AS binutils
RUN mkdir /opt/cross/
WORKDIR /opt/cross/

RUN curl -L http://ftpmirror.gnu.org/binutils/binutils-2.34.tar.bz2 | tar xj
RUN mkdir binutils-build
WORKDIR /opt/cross/binutils-build
RUN ../binutils-2.34/configure --target=sh4eb-nofpu-elf --prefix=$prefix  --disable-nls \
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

# cleaning up
RUN rm -rf /opt/cross/gcc-10.1.0

# FROM debian:bullseye-slim
# COPY --from=binutils /opt/cross/ /opt/cross/
# COPY --from=gcc /usr/local /usr/local
RUN apt-get -qq update && apt-get -qqy install make libmpc3 && apt-get -qqy clean

# Clone and make SDK
WORKDIR /opt/cross/
RUN git clone https://github.com/SnailMath/hollyhock-2.git
RUN mkdir /opt/cross/hollyhock-2/sdk
WORKDIR /opt/cross/hollyhock-2/sdk
RUN make -j$(nproc)

# TODO: Install doxygen and build docs?

# TODO: Install newlib and build it

# It'sthe cygwin version, is that ok ?
# version=1.14.0
# prefix=~/cross/src/hollyhock-2/sdk/newlib
# jobs=`nproc 2> /dev/null || echo 1`
# wget ftp://sourceware.org/pub/newlib/newlib-${version}.tar.gz
# tar xzfv newlib-${version}.tar.gz
# mkdir newlib-${version}-build
# cd newlib-${version}-build
# export TARGET_BINS="sh4eb-nofpu-elf"
# ./newlib-${version}/configure --target="sh-elf" --prefix=$PREFIX

# I used this to fix names :
# grep -rli 'sh-elf-' * | xargs -i@ sed -i 's/sh-elf-/sh4eb-nofpu-elf-/g' @
# grep -rli 'sh4eb-nofpu-elf-cc' * | xargs -i@ sed -i 's/sh4eb-nofpu-elf-cc/sh4eb-nofpu-elf-gcc/g' @

# make -j $jobs
# make install

# Also I think I got the "layer" thing : binutils is the layer you're creating => FROM <stuff> AS binutils

# 509s ... 700 more to go ! - it's a 1 core 2 cpu VM
# no worries
# Gonna beafk for 2 minutes, while it's building... 

# TODO: Compile test app in hollihock-2/app_template
# Really good idea ! And we could do binary diff-ing with an already-compiled binary in the repo ...
# I guess I can pr both .bin and .hhk files in the repo, and chat with snailmath later ...
# Or they could be in a separate repo, with just compiled binaries
# We could ship them, and use volumes to mount the file into the docker (I did once that ...)
# COPY ./app /var/app     <= ./app is your repo directory, /var/app is the VM dir
# yeah volume seems like a great idea
# also for dev env / web server there's the "CMD" : CMD ["node", "app.js", "--host", "0.0.0.0", "--port", "80"]
# cool, that's quite useful and simple

# I think we could setup a repo into the classpaddev git org when it's nicely done. Same for that docker on docker hub, we should later use a classpaddev org instead of my own account
# yep - fork the hollyhock-2 repo? and add a folder specifically for docker ?
# Or make a app template with the Docker and everything up to date
# Also with the docker that's posible to make a github actions addon ! Auto build here we go !
# https://dockerlabs.collabnix.com/beginners/volume/create-a-volume-mount-from-dockerfile.html




USER root

COPY setup.sh /tmp

RUN useradd -rm -d /home/$USERNAME -s /bin/bash -g root -G sudo -u 1001 $USERNAME
USER $USERNAME
WORKDIR /home/$USERNAME
# RUN cd /tmp && /tmp/setup.sh && rm -rf /tmp/setup.sh

# USER gitpod