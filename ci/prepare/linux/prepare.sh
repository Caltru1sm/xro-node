#!/bin/bash
set -euox pipefail

# NANO_BUILD_MINIMAL=true installs only what is needed to compile nano_node and
# nano_rpc, skipping Qt, valgrind and the X stack.
#
# Those are for the GUI wallet and the graphical test harness. CMakeLists only
# calls find_package(Qt5) inside `if(NANO_GUI OR RAIBLOCKS_GUI)` and ci/build.sh
# passes -DNANO_GUI=OFF, so a plain executables build never looks for them - it
# just waits while apt fetches ~700 MB of X fonts and Qt development headers
# first. On the arm64 runner that is a meaningful share of the build.
#
# Defaults to false, preserving the full install. The unit test, sanitizer and
# coverage workflows genuinely do run graphical tests under xvfb, and the
# release build produces the wallet, so this must stay opt-in rather than
# become the default. Only the node images set it.
COMPILER=${COMPILER:-gcc}
NANO_BUILD_MINIMAL=${NANO_BUILD_MINIMAL:-false}

echo "Compiler: '${COMPILER}'"
echo "Minimal build deps: '${NANO_BUILD_MINIMAL}'"

# Common dependencies needed for building & testing
DEBIAN_FRONTEND=noninteractive apt-get update -qq

PACKAGES=(
build-essential
g++
curl
wget
python3
zlib1g-dev
cmake
git
)

if [[ "${NANO_BUILD_MINIMAL}" != "true" ]]; then
  PACKAGES+=(
  qtbase5-dev
  qtchooser
  qt5-qmake
  qtbase5-dev-tools
  valgrind
  xorg xvfb xauth xfonts-100dpi xfonts-75dpi xfonts-scalable xfonts-cyrillic
  )
fi

DEBIAN_FRONTEND=noninteractive apt-get install -yqq "${PACKAGES[@]}"

# Compiler specific setup
$(dirname "$BASH_SOURCE")/prepare-${COMPILER}.sh