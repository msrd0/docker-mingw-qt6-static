FROM archlinux/archlinux:base-devel

LABEL org.opencontainers.image.url="https://github.com/msrd0/docker-mingw-qt6-static/pkgs/container/mingw-qt6-static"
LABEL org.opencontainers.image.title="mingw-qt6-static"
LABEL org.opencontainers.image.description="ArchLinux based Docker Image with a mingw toolchain to cross-compile Qt6 for both i686 and x86_64 targets"
LABEL org.opencontainers.image.source="https://github.com/msrd0/docker-mingw-qt6-static"

# install basic prerequisites and create build user
RUN pacman-key --init \
 && pacman -Syu --needed --noconfirm \
		git \
		jdk11-openjdk \
		jq \
		kotlin \
		mingw-w64 \
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

RUN set -eux; \
	sudo pacman-key --recv-keys B9E36A7275FC61B464B67907E06FE8F53CDC6A4C; \
	sudo pacman-key --lsign-key B9E36A7275FC61B464B67907E06FE8F53CDC6A4C; \
	sudo pacman -Sy --noconfirm mingw-w64-cmake-static; \
	PKG=ninja-samurai kotlin install.kts; \
	qtver=$(curl -s 'https://aur.archlinux.org/rpc/?v=5&type=info&arg[]=mingw-w64-qt6-base-static' | jq -r '.results[].Version' | tr '-' ' ' | awk '{print $1}'); \
	git clone https://aur.archlinux.org/qt6-base-headless; \
	pushd qt6-base-headless; \
	sed -E -i -e "s,_qtver=.*,_qtver=$qtver," PKGBUILD; \
	makepkg -si --skipchecksums --noconfirm; \
	popd; \
	rm -rf qt6-base-headless; \
	for pkg in \
		mingw-w64-rust-bin \
		mingw-w64-bzip2-static \
		mingw-w64-libjpeg-turbo-static \
		mingw-w64-libpng-static \
		mingw-w64-harfbuzz-static \
		mingw-w64-freetype2-static \
		mingw-w64-pcre2-static \
		mingw-w64-qt6-base-static; \
	do \
		PKG=$pkg kotlin install.kts; \
	done; \
	yes | sudo pacman -Scc
