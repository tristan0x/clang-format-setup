#!/bin/sh
set -e

# This script is meant for quick & install install via:
#   $ curl -fsSL <gist> -o git-cmake-format-install.sh
#   $ sh git-cmake-format-install.sh

CLANG_FORMAT_STYLE='https://raw.githubusercontent.com/tristan0x/clang-format-setup/master/.clang-format'
SUBMODULE_PATH=${1:-deps/git-cmake-format}

CMAKE=${CMAKE:-cmake}
GIT=${GIT:-git}
if ! `which "$CMAKE" >/dev/null 2>&1` ; then
    echo "Cannot find cmake executable. Abort" >&2
    exit 1
fi

if ! `which "$GIT" >/dev/null 2>&1` ; then
    echo "Cannot find git executable. Abort" >&2
    exit 1
fi

bold=$(tput bold) normal=$(tput sgr0)

if ! [ -d .git ] ; then
    echo "Cannot find .git directory. Abort" >&2
    exit 1
fi

if ! git diff-index --quiet HEAD -- ;then
    echo "Error: working copy has uncommitted changes. Abort" >&2
    exit 1
fi

if ! [ -f CMakeLists.txt ] ; then
    echo "Cannot find CMakeLists.txt. Abort" >&2
fi

if ! [ -f .gitmodules ] || ! grep -q "${SUBMODULE_PATH}" .gitmodules ; then
    echo "${bold}Adding '$SUBMODULE_PATH' git submodule${normal}"
    "$GIT" submodule add -b bbp \
        https://github.com/BlueBrain/git-cmake-format.git \
        "$SUBMODULE_PATH"
fi

if ! grep -q "${SUBMODULE_PATH}" CMakeLists.txt ; then
    echo "${bold}Patching CMakefile to include '$SUBMODULE_PATH'${normal}"
    sed -i "s@^\(project(.*\)\$@\1\nadd_subdirectory(${SUBMODULE_PATH})@" CMakeLists.txt
    "$GIT" add CMakeLists.txt
fi

if ! [ -f .clang-format ] ; then
    echo "${bold}Adding HPC team .clang-format${normal}"
    curl -fsSL "$CLANG_FORMAT_STYLE" -o .clang-format
    "$GIT" add .clang-format
fi

if ! [ -d build ] ; then
    echo "${bold}Building CMake project in new 'build' directory${normal}"
    mkdir build
    (cd build ; "$CMAKE" .. || true)
else
    echo "${bold}Building CMake project in 'build' directory${normal}"
    (cd build ; "$CMAKE" . || true)
fi

if [ -f build/CMakeCache.txt ] ; then
    echo "${bold}Formatting C/C++ source files:${normal}"
    clang_format=`grep ^CLANG_FORMAT_EXECUTABLE: build/CMakeCache.txt | cut -d= -f2`
    if [ "x$clang_format" = x ] ;then
      clang_format=clang-format
    fi
    IFS=$"\n"
    git ls-files | while IFS= read -r file
    do
        case "$file" in
            *.h|*.cpp|*.hpp|*.c|*.cc|*.hh|*.cxx|*.hxx)
                echo "-- $file"
                "$clang_format" -style=file -i "$file"
                git add "$file"
            ;;
        esac
    done
    IFS="$OLD_IFS"
fi

echo "${bold}Listing changes with command: git status${normal}"
"$GIT" status
