#!/usr/bin/bash

# This script is for MSYS2's CLANG64 environment on Windows
# Beware nasal demons anywhere else

set -euo pipefail

export LANG=C.UTF-8
export LC_ALL=C.UTF-8

originrepo='https://github.com/derfuhrervonholle/plb'
upstreamrepo='https://github.com/PrismLauncher/PrismLauncher'

pkgverprev="$(curl -LsIX GET -o /dev/null -w '%{url_effective}' "${originrepo}/releases/latest" | sed "s;${originrepo}/releases/tag/;;g")"
pkgver="$(curl -LsIX GET -o /dev/null -w '%{url_effective}' "${upstreamrepo}/releases/latest" | sed "s;${upstreamrepo}/releases/tag/;;g")"

echo "pkgverprev: ${pkgverprev}"
echo "pkgver    : ${pkgver}"

if [[ "${pkgverprev}" = "${pkgver}" ]]; then
	echo 'Not outdated, quitting'
	echo 'old=false' >> "${GITHUB_OUTPUT}"
	exit 0
fi

echo 'Outdated, running'
echo 'old=true' >> "${GITHUB_OUTPUT}"

echo "tname=${pkgver}" >> "${GITHUB_OUTPUT}"

pacman -S --needed --noconfirm \
	base-devel \
	patch \
	zip \
	mingw-w64-clang-x86_64-cmake \
	mingw-w64-clang-x86_64-ninja \
	mingw-w64-clang-x86_64-cc \
	mingw-w64-clang-x86_64-extra-cmake-modules \
	mingw-w64-clang-x86_64-ccache \
	mingw-w64-clang-x86_64-qt6-base \
	mingw-w64-clang-x86_64-qt6-5compat \
	mingw-w64-clang-x86_64-qt6-svg \
	mingw-w64-clang-x86_64-qt6-imageformats \
	mingw-w64-clang-x86_64-qt6-networkauth \
	mingw-w64-clang-x86_64-quazip-qt6 \
	mingw-w64-clang-x86_64-zlib \
	mingw-w64-clang-x86_64-tomlplusplus \
	mingw-w64-clang-x86_64-cmark \
	mingw-w64-clang-x86_64-qrencode

curl -Lo java.zip 'https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u442-b06/OpenJDK8U-jdk_x64_windows_hotspot_8u442b06.zip'
bsdtar -xf java.zip
export JAVA_HOME="$(cygpath -aw jdk8u442-b06)"

export MSYS=winsymlinks:native

curl -LO "https://github.com/PrismLauncher/PrismLauncher/releases/download/${pkgver}/PrismLauncher-${pkgver}.tar.gz"
tar -xf "PrismLauncher-${pkgver}.tar.gz"

cd "PrismLauncher-${pkgver}"
find .. -mindepth 1 -maxdepth 1 -type f -name '*.patch' -exec patch -Np1 -i {} \;
cd ..

installdir='install'
cmake \
	-Wno-dev \
	-DCMAKE_BUILD_TYPE=Release \
	-G Ninja \
	-DCMAKE_INSTALL_PREFIX="${installdir}" \
	-DENABLE_LTO=ON \
	-DLauncher_UPDATER_GITHUB_REPO="${originrepo}" \
	-DLauncher_BUILD_ARTIFACT='Windows-MinGW-w64-' \
	-S "PrismLauncher-${pkgver}" \
	-B build \
	-DCMAKE_CXX_COMPILER_LAUNCHER=ccache

cmake --build build

ctest --test-dir build --output-on-failure || true

cmake --install build
cmake --install build --component portable

mtxt="${installdir}/manifest.txt"
find "$(cygpath -au "${installdir}")" -type f -exec realpath --relative-to="$(cygpath -au "${installdir}")" {} \+ > "${mtxt}"

(cd "${installdir}"; zip -r - .) > "PrismLauncher-Windows-MinGW-w64-Portable-${pkgver}.zip"
