#!/bin/bash

# we pin the mason version to avoid changes in mason breaking builds
PULL_MASON_BRANCH="v0.20.0"  # this must be branch or tag name
PULL_MASON_COMMIT="v0.20.0"  # this can also be commit hash
PULL_MASON_REPO="https://github.com/mapbox/mason.git"

ICU_VERSION="57.1"
BOOST_VERSION="1.65.1"

function install_mason_deps() ( # subshell
    set -o errexit
    set -o nounset
    install icu ${ICU_VERSION}
    install proj 4.9.3
    install libgdal 2.1.3
    install boost ${BOOST_VERSION}
    install boost_libsystem ${BOOST_VERSION}
    install boost_libfilesystem ${BOOST_VERSION}
    install cairo 1.14.8 libcairo
    # some mapnik headers we use also include harfbuzz
    install freetype 2.7.1 libfreetype
    install harfbuzz 1.4.4-ft libharfbuzz
    # linking requests some libraries that it should not,
    # when they're statically linked into libmapnik;
    # add them here until this is fixed in mapnik-config
    install pixman 0.34.0 libpixman-1
    install webp 0.6.0 libwebp
    install boost_libregex_icu57 ${BOOST_VERSION}
    # deps needed by python-mapnik (not mapnik core)
    install boost_libthread ${BOOST_VERSION}
    install boost_libpython ${BOOST_VERSION}
)

function install() {
    MASON_PLATFORM_ID=$(mason env MASON_PLATFORM_ID)
    if [ ! -d "$(mason_packages)/$MASON_PLATFORM_ID/$1/" ]; then
        mason install $1 $2
        mason link $1 $2
    fi
}

function mason_packages() {
    printf '%s\n' "${MASON_ROOT:-mason_packages}"
}

function prepend_unique() {
    # Bash on Travis OSX doesn't know local -n,
    # indirect variable reference should be fine
    local list=${!1}
    case "$list" in
        "$2"| "$2":*) : already there ;;
        *:"$2") list=$2:${list%:"$2"} ;;
        *:"$2":*) list=$2:${list%:"$2":*}:${list##*:"$2":} ;;
        '') list=$2 ;;
        *) list=$2:$list ;;
    esac
    eval $1=\$list
}

function setup_runtime_settings() {
    local MASON_LINKED_ABS=$(mason_packages)/.link
    export PROJ_LIB=${MASON_LINKED_ABS}/share/proj
    export ICU_DATA=${MASON_LINKED_ABS}/share/icu/${ICU_VERSION}
    export GDAL_DATA=${MASON_LINKED_ABS}/share/gdal
    prepend_unique PATH "${MASON_LINKED_ABS}/bin"
}

function setup_mason() {
    if ! test -d mason; then
        git clone -n --depth=10 --branch="$PULL_MASON_BRANCH" "$PULL_MASON_REPO" mason || return
    fi
    if ! git -C mason rev-parse -q --verify "$PULL_MASON_COMMIT" >/dev/null; then
        git -C mason fetch --deepen=10 origin "$PULL_MASON_BRANCH" || true # non-fatal
    fi
    git -C mason checkout --detach "$PULL_MASON_COMMIT" -- || return
    export CXX=${CXX:-clang++}
    export CC=${CC:-clang}
    prepend_unique PATH "$PWD/mason"
}

setup_mason
