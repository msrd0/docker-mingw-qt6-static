FROM archlinux/archlinux:base-devel

# install basic prerequisites and create build user
RUN pacman -Sy --needed --noconfirm git jdk11-openjdk kotlin mingw-w64 sudo \
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

# install the freetype-bootstrap library
RUN PKG=mingw-w64-freetype2-bootstrap kotlin install.kts

# install the cairo-bootstrap library
RUN PKG=mingw-w64-cairo-bootstrap kotlin install.kts

# install the harfbuzz library
RUN PKG=mingw-w64-harfbuzz kotlin install.kts

# remove the bootstrap library and replace with the real freetype2
RUN PKG=mingw-w64-freetype2 kotlin install.kts

# install the librsvg library
RUN PKG=mingw-w64-librsvg kotlin install.kts

# remove the bootstrap library and replace with real cairo
RUN PKG=mingw-w64-cairo kotlin install.kts

# finally, build and install the qt6 package
RUN PKG=mingw-w64-qt6-base-static kotlin install.kts
