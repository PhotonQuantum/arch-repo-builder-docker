#!/bin/bash
set -euo pipefail
export AUR_REPO=$REPO
export AUR_DBROOT=$(pwd)/build-dir/

sudo pacman -Syu --noconfirm

git clone https://aur.archlinux.org/ossfs-git.git
git clone https://aur.archlinux.org/aurutils.git

pushd ossfs-git
makepkg -si --noconfirm
popd

pushd aurutils
makepkg -si --noconfirm
popd

# mount ossfs
echo $BUCKET:$APIKEY:$APISECRET > .passwd-ossfs
chmod 600 .passwd-ossfs

mkdir target-dir build-dir
ossfs $BUCKET target-dir -ourl=$ENDPOINT

# prepare repo
set +e
rsync -rlP --delete target-dir/ build-dir/
set -e
rm build-dir/$REPO.db build-dir/$REPO.files
ln -s $(pwd)/build-dir/$REPO.db.tar.zst $(pwd)/build-dir/$REPO.db
ln -s $(pwd)/build-dir/$REPO.files.tar.zst $(pwd)/build-dir/$REPO.files
REPO_CONF=$(cat <<-END
[$REPO]
SigLevel = Never
Server = file://$(pwd)/build-dir/
END
)
echo "$REPO_CONF" | sudo tee -a /etc/pacman.conf > /dev/null
sudo pacman -Syu

# build packages
CURRENT_TIME=$(date +"%s")
mkdir -p build-dir/log
set +e
./build.sh 2>&1 | tee build-dir/log/build.$CURRENT_TIME.log 
set -e

# update meta data
./arch-db-meta-rs build-dir/$REPO.db build-dir/meta.json
date +"%s" > build-dir/lastupdate

# sync back to remote
set +e
rsync -rLP --delete build-dir/ target-dir/
set -e
sync
fusermount -u target-dir
