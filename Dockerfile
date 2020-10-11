FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive \
  PATH=/root/.cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  LD_LIBRARY_PATH=/lib/x86_64-linux-gnu:/lib:/usr/lib:/usr/local/lib:/usr/local/lib64 \
  PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/lib/pkgconfig:/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig \
  RUSTFLAGS="-C target-cpu=native"

RUN apt-get update \
  && apt-get upgrade -y \
  && apt-get install -y gcc g++ cmake yasm nasm git pkg-config meson curl \
  libchromaprint-dev frei0r-plugins-dev libgnutls28-dev ladspa-sdk libaom-dev \
  liblilv-dev libiec61883-dev libavc1394-dev libass-dev libbluray-dev \
  libbs2b-dev libcaca-dev libcodec2-dev libdc1394-dev libdrm-dev flite1-dev \
  libmp3lame-dev libmysofa-dev libopenjp2-7-dev libopenmpt-dev \
  libopus-dev libpulse-dev libgme-dev libgsm1-dev librsvg2-dev \
  librtmp-dev librubberband-dev libshine-dev libsnappy-dev \
  libsoxr-dev libssh-dev libspeex-dev libtheora-dev \
  libtwolame-dev libvidstab-dev libvpx-dev libwebp-dev \
  libx264-dev libx265-dev libxvidcore-dev libnuma-dev libzmq3-dev \
  libzvbi-dev libopenal-dev ocl-icd-opencl-dev libomxil-bellagio-dev \
  libjack-dev libcdio-dev libcdio-paranoia-dev libffmpeg-nvenc-dev \
  libsdl2-dev \
  && curl https://sh.rustup.rs -sSf -o /usr/local/bin/rust-init \
  && chmod +x /usr/local/bin/rust-init \
  && rust-init -y \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/local/src

RUN git clone --depth=1 https://github.com/AOMediaCodec/SVT-AV1 SVT-AV1 \
  && git clone --depth=1 https://github.com/OpenVisualCloud/SVT-HEVC SVT-HEVC \
  && git clone --depth=1 https://github.com/OpenVisualCloud/SVT-VP9 SVT-VP9 \
  && git clone --depth=1 https://code.videolan.org/videolan/dav1d.git dav1d \
  && git clone --depth=1 https://github.com/xiph/rav1e rav1e \
  && git clone --depth=1 https://github.com/cisco/openh264 openh264 \
  # for SVT-HEVC or SVT-VP9
  # && git clone --depth=1 -b n4.3.1 https://github.com/FFmpeg/FFmpeg ffmpeg
  && git clone --depth=1 https://github.com/FFmpeg/FFmpeg ffmpeg

RUN cd SVT-AV1 \
  && cd Build \
  && cmake .. -G"Unix Makefiles" -DCMAKE_BUILD_TYPE=Release \
  && make -j $(nproc) \
  && make install \
  && make clean

RUN cd SVT-HEVC \
  && cd Build/linux \
  && ./build.sh release \
  && cd Release \
  && make -j $(nproc) \
  && make install \
  && make clean

RUN cd SVT-VP9 \
  && cd Build \
  && cmake .. -DCMAKE_BUILD_TYPE=Release \
  && make -j $(nproc) \
  && make install \
  && make clean

RUN cd dav1d \
  && mkdir build \
  && cd build \
  && meson .. \
  && ninja -j $(nproc) \
  && ninja install \
  && ninja clean

RUN cd rav1e \
  && cargo install cargo-c \
  && cargo cinstall --release \
  --prefix=/usr/local \
  --libdir=/usr/local/lib \
  --includedir=/usr/local/include

RUN cd openh264 \
  && make -j $(nproc) \
  && make install \
  && make clean

RUN cd ffmpeg \
  # for SVT-HEVC
  # && git apply /usr/local/src/SVT-HEVC/ffmpeg_plugin/0001*.patch \
  # for SVT-VP9
  # && git apply /usr/local/src/SVT-VP9/ffmpeg_plugin/master-0001-Add-ability-for-ffmpeg-to-run-svt-vp9.patch \
  && C_INCLUDE_PATH=/usr/local/include/rav1e \
  ./configure --prefix=/usr --extra-version=extra \
  --toolchain=hardened --libdir=/usr/lib/x86_64-linux-gnu --incdir=/usr/include/x86_64-linux-gnu --extra-cflags=-march=native --enable-shared \
  --arch=amd64 --enable-gpl --disable-stripping --enable-avresample --disable-filter=resample --enable-gnutls --enable-ladspa --enable-libaom \
  --enable-libass --enable-libbluray --enable-libbs2b --enable-libcaca --enable-libcdio --enable-libcodec2 --enable-libflite --enable-libfontconfig --enable-libfreetype \
  --enable-libfribidi --enable-libgme --enable-libgsm --enable-libjack --enable-libmp3lame --enable-libmysofa --enable-libopenjpeg --enable-libopenmpt --enable-libopus \
  --enable-libpulse --enable-librsvg --enable-librubberband --enable-libshine --enable-libsnappy --enable-libsoxr --enable-libspeex --enable-libssh --enable-libtheora \
  --enable-libtwolame --enable-libvidstab --enable-libvorbis --enable-libvpx --enable-libwebp --enable-libx265 --enable-libxml2 --enable-libxvid \
  --enable-libzmq --enable-libzvbi --enable-lv2 --enable-omx --enable-openal --enable-opencl --enable-opengl --enable-sdl2 --enable-libdc1394 --enable-libdrm \
  --enable-libiec61883 --enable-nvenc --enable-chromaprint --enable-frei0r --enable-libx264 --enable-librtmp --enable-libvpx \
  --enable-libopenh264 --enable-libopenjpeg --enable-libdav1d --enable-librav1e --enable-libsvtav1 \
  # for SVT-HEVC
  # --enable-libsvthevc \
  # for SVT-VP9
  # --enable-libsvtvp9 \
  && C_INCLUDE_PATH=/usr/local/include/rav1e \
  make -j $(nproc) \
  && make install \
  && make clean

WORKDIR /work

CMD [ "/bin/bash" ]

