#!/bin/bash
set -euo pipefail

AURVCS=${AURVCS:-.*-(cvs|svn|git|hg|bzr|darcs)$}

# let custom_pkgs: List[string]
pushd build-dir/custom
readarray -t _custom_pkgs <<< $(ls -d */)
custom_pkgs=$(echo "${_custom_pkgs[@]%/}")
popd

# build custom packages
echo "[+] Building custom packages"
for custom_package in "${custom_pkgs[@]}"; do
    echo "[-] Building ${custom_package}"
    pushd build-dir/custom/${custom_package}
    set +e
    aur build -- --noconfirm -cs
    set -e
    popd
done

# sync packages
echo "[+] Building normal packages"
packages=$(aur repo $REPO --list --status-file=db|aur vercmp --quiet)
for package in "${packages[@]}"; do
    if [[ ! "${custom_pkgs[@]}" =~ "${package}" ]]; then
        echo "[-] Building ${package}"
        set +e
        aur sync -n "${package}" --noview --ignore ${custom_pkgs[@]}
        set -e
    fi
done

echo "[+] Building VCS packages"
mapfile -t vcs_packages < <(aur repo --list | cut -f1 | grep -E "$AURVCS")
for vcs_package in "${vcs_packages[@]}"; do
    if [[ ! "${custom_pkgs[@]}" =~ "${vcs_package}" ]]; then
        echo "[-] Building ${vcs_package}"
        set +e
        aur sync -n "${vcs_package}" --no-ver --noview --ignore ${custom_pkgs[@]}
        set -e
    fi
done

# remove old packages
paccache -dk 1 -c build-dir/
