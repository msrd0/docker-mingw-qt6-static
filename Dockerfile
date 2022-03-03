FROM archlinux/archlinux:base-devel

# install basic prerequisites and create build user
RUN pacman-key --init \
 && pacman-key --recv-keys B9E36A7275FC61B464B67907E06FE8F53CDC6A4C \
 && pacman-key --lsign-key B9E36A7275FC61B464B67907E06FE8F53CDC6A4C \
 && pacman -Sy --needed --noconfirm git jdk11-openjdk kotlin mingw-w64 sudo \
 && useradd -m -d /home/user user \
 && echo "user ALL=(ALL) NOPASSWD: ALL" >/etc/sudoers.d/user \
 && yes | pacman -Scc

# copy our pacman and makepkg config
COPY pacman.conf /etc/pacman.conf
COPY makepkg.conf /etc/makepkg.conf

USER user
WORKDIR /home/user

# copy install script
COPY install.kts .

# install samurai to replace ninja
RUN PKG=ninja-samurai kotlin install.kts

# we might as well use rustup's binaries if we otherwise use those binaries to
# compile the compiler
RUN PKG=mingw-w64-rust-bin kotlin install.kts

# install bzip2 library
RUN PKG=mingw-w64-bzip2-static kotlin install.kts

# install the harfbuzz library
RUN PKG=mingw-w64-harfbuzz-static kotlin install.kts

# remove the bootstrap library and replace with the real freetype2
RUN PKG=mingw-w64-freetype2-static kotlin install.kts

# install the pango library
#RUN PKG=mingw-w64-pango-static kotlin install.kts

RUN PKG=mingw-w64-libjpeg-turbo-static kotlin install.kts
RUN PKG=mingw-w64-libpng-static kotlin install.kts
RUN PKG=mingw-w64-pcre2-static kotlin install.kts

# finally, build and install the qt6 package
RUN PKG=mingw-w64-qt6-base-static kotlin install.kts
