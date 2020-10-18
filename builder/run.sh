#!/bin/bash
set -euo pipefail
export TARGET_DIR=/target
export BUILD_DIR=build-dir

export AUR_REPO=$REPO
export AUR_DBROOT=$(pwd)/$BUILD_DIR/

export PACMAN=powerpill

sudo powerpill -S archlinuxcn-keyring archlinux-keyring --noconfirm --needed
sudo powerpill -Syu --noconfirm

git clone https://aur.archlinux.org/aurutils.git

pushd aurutils
makepkg -si --noconfirm
popd

# prepare repo
mkdir $BUILD_DIR
set +e
rsync -rltP --delete $TARGET_DIR/ $BUILD_DIR/
set -e
rm $BUILD_DIR/$REPO.db $BUILD_DIR/$REPO.files
ln -s $(pwd)/$BUILD_DIR/$REPO.db.tar.zst $(pwd)/$BUILD_DIR/$REPO.db
ln -s $(pwd)/$BUILD_DIR/$REPO.files.tar.zst $(pwd)/$BUILD_DIR/$REPO.files
REPO_CONF=$(cat <<-END
[$REPO]
SigLevel = Never
Server = file://$(pwd)/$BUILD_DIR/
END
)
echo "$REPO_CONF" | sudo tee -a /etc/pacman.conf > /dev/null
sudo powerpill -Syu

# build packages
CURRENT_TIME=$(date +"%s")
mkdir -p $BUILD_DIR/log
set +e
./build.sh 2>&1 | tee $BUILD_DIR/log/build.$CURRENT_TIME.log 
cp failed_pkgs.log $BUILD_DIR/log/failed.$CURRENT_TIME.log
set -e

# update meta data
./arch-db-meta-rs $BUILD_DIR/$REPO.db $BUILD_DIR/meta.json
echo $CURRENT_TIME > $BUILD_DIR/lastupdate

# sync back to remote
set +e
rsync -rLtP --delete $BUILD_DIR/ $TARGET_DIR/
set -e
sync

# fix mime
sudo pacman -S python-pip --noconfirm
sudo pip install oss2
python ./fix-mime.py
