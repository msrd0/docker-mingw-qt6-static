FROM ghcr.io/msrd0/qt6-headless

LABEL org.opencontainers.image.title="mingw-qt6-static"
LABEL org.opencontainers.image.description="ArchLinux based Docker Image with a mingw toolchain to cross-compile Qt6 for both i686 and x86_64 targets"

# we can't use pipefail because we use yes|pacman, so we'll disable DL4006 everywhere
# also shellcheck is dumb and doesn't realize -e here, so we'll disable SC2164 as well
SHELL ["/usr/bin/bash", "-eux", "-c"]

# install basic prerequisites and create build user
# hadolint ignore=DL4006
RUN sudo pacman -Syu --needed --noconfirm \
		jdk11-openjdk \
		kotlin; \
	yes | sudo pacman -Scc

# copy install script
COPY install.kts .

# we'll use samu instead of ninja for deterministic builds
# hadolint ignore=DL4006
RUN PKG=ninja-samurai kotlin install.kts; \
	yes | sudo pacman -Scc

# install mingw stuff from the arch repo but patched
RUN mkdir mingw-w64-crt
COPY mingw-w64-crt/PKGBUILD ./mingw-w64-crt/PKGBUILD
# hadolint ignore=DL4006,SC2164
RUN pushd mingw-w64-crt; \
	gpg --recv-keys CAF5641F74F7DFBA88AE205693BDB53CD4EBC740; \
	makepkg -si --noconfirm; \
	popd; \
	sudo pacman -S --needed --noconfirm mingw-w64; \
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
		mingw-w64-freetype2-static-bootstrap \
		mingw-w64-fontconfig-static \
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
