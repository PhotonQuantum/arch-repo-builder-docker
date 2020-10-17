FROM archlinux:latest

COPY mirrorlist /etc/pacman.d/mirrorlist

COPY makepkg.conf /etc/makepkg.conf

COPY pacman.conf /etc/pacman.conf

RUN pacman -Syu --noconfirm

RUN pacman -S archlinuxcn-keyring --noconfirm

RUN pacman -S powerpill --noconfirm

RUN powerpill -S pacman-contrib base-devel git rsync fuse mime-types --needed --noconfirm

RUN paccache -r -k 0

RUN useradd -m -s /bin/bash -d /build build

RUN echo "build ALL=NOPASSWD: ALL" >> /etc/sudoers

WORKDIR /build

COPY run.sh build.sh arch-db-meta-rs ./

USER build

ENTRYPOINT ["bash", "run.sh"]
