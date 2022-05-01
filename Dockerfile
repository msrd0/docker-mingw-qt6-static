FROM archlinux/archlinux:base-devel

LABEL org.opencontainers.image.url="https://github.com/msrd0/docker-mingw-qt6-static/pkgs/container/mingw-qt6-static"
LABEL org.opencontainers.image.title="mingw-qt6-static"
LABEL org.opencontainers.image.description="ArchLinux based Docker Image with a mingw toolchain to cross-compile Qt6 for both i686 and x86_64 targets"
LABEL org.opencontainers.image.source="https://github.com/msrd0/docker-mingw-qt6-static"

# we can't use pipefail because we use yes|pacman, so we'll disable DL4006 everywhere
SHELL ["/usr/bin/bash", "-eux", "-c"]

# install basic prerequisites and create build user
# hadolint ignore=DL4006
RUN pacman -Syu --needed --noconfirm \
		git \
		jdk11-openjdk \
		jq \
		kotlin \
		sudo \
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

# we'll use samu instead of ninja for deterministic builds
# hadolint ignore=DL4006
RUN PKG=ninja-samurai kotlin install.kts; \
	yes | sudo pacman -Scc

# install mingw stuff from the arch repo but patched
RUN mkdir mingw-w64-crt
COPY mingw-w64-crt/PKGBUILD ./mingw-w64-crt/PKGBUILD
RUN pushd mingw-w64-crt; \
	gpg --recv-keys CAF5641F74F7DFBA88AE205693BDB53CD4EBC740; \
	makepkg -si --noconfirm; \
	popd; \
	sudo pacman -S --needed --noconfirm mingw-w64; \
	yes | sudo pacman -Scc

# install qt6-headless host tools
# hadolint ignore=DL4006
RUN qtver=$(curl -s 'https://aur.archlinux.org/rpc/?v=5&type=info&arg[]=mingw-w64-qt6-base-static' | jq -r '.results[].Version' | tr '-' ' ' | awk '{print $1}'); \
	git clone https://aur.archlinux.org/qt6-base-headless; \
	pushd qt6-base-headless; \
	sed -E -i -e "s,_qtver=.*,_qtver=$qtver," PKGBUILD; \
	makepkg -si --skipchecksums --noconfirm; \
	popd; \
	rm -rf qt6-base-headless; \
	sudo pacman -Rscn --noconfirm \
		postgresql \
		xmlstarlet; \
	yes | sudo pacman -Scc

# install all the mingw stuff
# hadolint ignore=DL4006,SC2086
RUN pkgs=" \
		mingw-w64-cmake-static \
		mingw-w64-rust-bin \
		mingw-w64-graphite \
		mingw-w64-bzip2-static \
		mingw-w64-brotli-static \
		mingw-w64-libjpeg-turbo-static \
		mingw-w64-libpng-static \
		mingw-w64-freetype2-bootstrap \
		mingw-w64-cairo-bootstrap \
		mingw-w64-harfbuzz-static \
		mingw-w64-freetype2-static \
		mingw-w64-pcre2-static \
		mingw-w64-qt6-base-static \
	"; \
	deps=" \
		mingw-w64-configure \
		mingw-w64-meson \
	"; \
	for pkg in $deps $pkgs; do \
		PKG=$pkg kotlin install.kts; \
	done; \
	sudo pacman -Rscn --noconfirm $deps; \
	yes | sudo pacman -Scc
