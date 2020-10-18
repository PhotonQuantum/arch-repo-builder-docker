#!/bin/bash
set -euo pipefail

AURVCS=${AURVCS:-.*-(cvs|svn|git|hg|bzr|darcs)$}

# let custom_pkgs: List[string]
mkdir -p $BUILD_DIR/custom
pushd $BUILD_DIR/custom
set +e
ls -d */
[ $? == 0 ] && has_custom_pkgs=true || has_custom_pkgs=false
set -e
if $has_custom_pkgs; then
    readarray -t _custom_pkgs <<< $(ls -d */)
    custom_pkgs=$(echo "${_custom_pkgs[@]%/}")
fi
popd

failed_pkgs=()

# build custom packages
if $has_custom_pkgs; then
    echo "[+] Building custom packages"
    for custom_package in "${custom_pkgs[@]}"; do
        echo "[-] Building ${custom_package}"
        pushd $BUILD_DIR/custom/${custom_package}
        set +e
        aur build -f -- --noconfirm -cs
        [ $? -ne 0 ] && failed_pkgs+=($custom_package)
        set -e
        popd
    done
fi

# sync packages
echo "[+] Building normal packages"
packages=$(aur repo $REPO --list --status-file=db|aur vercmp --quiet)
for package in "${packages[@]}"; do
    if [[ ! "${custom_pkgs[@]}" =~ "${package}" ]]; then
        echo "[-] Building ${package}"
        set +e
        if $has_custom_pkgs; then
            aur sync -n "${package}" --noview --ignore ${custom_pkgs[@]}
        else
            aur sync -n "${package}" --noview
        fi
        [ $? -ne 0 ] && failed_pkgs+=($package)
        set -e
    fi
done

echo "[+] Building VCS packages"
mapfile -t vcs_packages < <(aur repo --list | cut -f1 | grep -E "$AURVCS")
for vcs_package in "${vcs_packages[@]}"; do
    if [[ ! "${custom_pkgs[@]}" =~ "${vcs_package}" ]]; then
        echo "[-] Building ${vcs_package}"
        set +e
        if $has_custom_pkgs; then
            aur sync -f -n "${vcs_package}" --no-ver --noview --ignore ${custom_pkgs[@]}
        else
            aur sync -f -n "${vcs_package}" --no-ver --noview
        fi
        [ $? -ne 0 ] && failed_pkgs+=($vcs_package)
        set -e
    fi
done

# remove old packages
paccache -rk 3 -c $BUILD_DIR/

echo "${failed_pkgs[@]}" > failed_pkgs.log
