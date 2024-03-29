#!/bin/bash

BUILD_DIR="$(cd $(dirname $0) && pwd)"

if [[ -z "$TMUX_VERSION" ]]; then
  TMUX_VERSION=3.2a
fi

if [[ -z "$NCURSES_VERSION" ]]; then
  NCURSES_VERSION=6.2
fi

if [[ -z "$LIBEVENT_VERSION" ]]; then
  LIBEVENT_VERSION=2.1.12-stable
fi

if [[ -z "$UTF8PROC_VERSION" ]]; then
  UTF8PROC_VERSION=2.6.1
fi

BUILD_PREBUILT_DEP="$BUILD_DIR/prebuilt/dep"
BUILD_PREBUILT_TMUX="$BUILD_DIR/prebuilt/tmux"

echo "We need wget or curl, tar, C compiler(gcc for default), cmake, make, "
echo "BUILD_DIR=$BUILD_DIR"
echo "BUILD_PREBUILT_DEP=$BUILD_PREBUILT_DEP"
echo "BUILD_PREBUILT_TMUX=$BUILD_PREBUILT_TMUX"
sleep 2

# export CC=musl-gcc
# export CFLAGS="-fPIC -I$BUILD_PREBUILT_DEP/dep/include"
echo "$CFLAGS" | grep -i fpic >/dev/null 2>&1
if [[ 0 -eq $? ]]; then
  export CFLAGS="$CFLAGS -I$BUILD_PREBUILT_DEP/dep/include"
else
  export CFLAGS="$CFLAGS -fPIC -I$BUILD_PREBUILT_DEP/dep/include"
fi
if [[ "x$PKG_CONFIG_PATH" == "x" ]]; then
  export PKG_CONFIG_PATH="$BUILD_PREBUILT_DEP/lib/pkgconfig"
else
  export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$BUILD_PREBUILT_DEP/lib/pkgconfig"
fi

function download_pkg() {
  if [[ $# -gt 1 ]]; then
    FILE_NAME="$2"
  else
    FILE_NAME="$(basename $1)"
  fi

  if [[ ! -e "$FILE_NAME" ]]; then
    which curl >/dev/null 2>&1
    if [[ 0 -eq $? ]]; then
      echo "run: curl -L -k \"$1\" -o \"$FILE_NAME\""
      curl -L -k "$1" -o "$FILE_NAME"
    else
      which wget >/dev/null 2>&1
      if [[ 0 -eq $? ]]; then
        echo "run: wget --no-check-certificate \"$1\" -O \"$FILE_NAME\""
        wget --no-check-certificate "$1" -O "$FILE_NAME"
      else
        echo "can not find wget or curl, download $1 failed."
        exit 1
      fi
    fi
  fi

  return $?
}

# ============ build libevent ============
cd "$BUILD_DIR"
download_pkg https://github.com/libevent/libevent/releases/download/release-$LIBEVENT_VERSION/libevent-$LIBEVENT_VERSION.tar.gz
if [[ 0 -ne $? ]]; then
  echo "download libevent failed"
  exit 1
fi
if [[ -e "libevent-$LIBEVENT_VERSION" ]]; then
  rm -rf "libevent-$LIBEVENT_VERSION"
fi
tar -axvf libevent-$LIBEVENT_VERSION.tar.gz

if [[ ! -e "libevent-$LIBEVENT_VERSION" ]]; then
  echo "unpack libevent failed"
  exit 1
fi

cd libevent-$LIBEVENT_VERSION
./configure --prefix="$BUILD_PREBUILT_DEP" --disable-openssl --enable-shared=no --enable-static=yes --with-pic
make -j4
make install
if [[ 0 -ne $? ]]; then
  echo "build libevent failed"
  exit 1
fi

# ============ build ncurses ============
cd "$BUILD_DIR"
download_pkg https://invisible-mirror.net/archives/ncurses/ncurses-$NCURSES_VERSION.tar.gz
if [[ 0 -ne $? ]]; then
  echo "download ncurses failed"
  exit 1
fi
if [[ -e "ncurses-$NCURSES_VERSION" ]]; then
  rm -rf "ncurses-$NCURSES_VERSION"
fi
tar -axvf ncurses-$NCURSES_VERSION.tar.gz

if [[ ! -e "ncurses-$NCURSES_VERSION" ]]; then
  echo "unpack ncurses failed"
  exit 1
fi

cd ncurses-$NCURSES_VERSION
# ncursesw: --enable-ext-colors --enable-widec
# build with clang: CC=clang CXX=clang++ CFLAGS="-Wno-unused-command-line-argument" AR=llvm-ar LD=lld
./configure --prefix="$BUILD_PREBUILT_DEP" --without-cxx --without-cxx-binding --with-termlib --enable-termcap \
--enable-ext-colors --enable-ext-mouse --enable-bsdpad --enable-opaque-curses \
--with-terminfo-dirs=/etc/terminfo:/usr/share/terminfo:/lib/terminfo \
--with-termpath=/etc/termcap:/usr/share/misc/termcap \

#    --with-fallbacks="linux,xterm,xterm-color,xterm-256color,vt100"
#    --with-database=misc/terminfo.src

make -j4
make install
if [[ 0 -ne $? ]]; then
  echo "build ncurses failed"
  exit 1
fi

# ============ build utf8proc ============
cd "$BUILD_DIR"
download_pkg https://github.com/JuliaLang/utf8proc/archive/v$UTF8PROC_VERSION.tar.gz utf8proc-$UTF8PROC_VERSION.tar.gz
if [[ 0 -ne $? ]]; then
  echo "download utf8proc failed"
  exit 1
fi

if [[ -e "utf8proc-$UTF8PROC_VERSION" ]]; then
  rm -rf "utf8proc-$UTF8PROC_VERSION"
fi
tar -axvf utf8proc-$UTF8PROC_VERSION.tar.gz

if [[ ! -e "utf8proc-$UTF8PROC_VERSION" ]]; then
  echo "unpack utf8proc failed"
  exit 1
fi

mkdir -p utf8proc-$UTF8PROC_VERSION/build
cd utf8proc-$UTF8PROC_VERSION/build
cmake .. -DCMAKE_INSTALL_PREFIX="$BUILD_PREBUILT_DEP" -DBUILD_SHARED_LIBS=OFF
cmake --build .
if [[ 0 -ne $? ]]; then
  echo "build utf8proc failed"
  exit 1
fi
# install
cmake --build . --target install

# ============ build tmux ============
cd "$BUILD_DIR"
download_pkg https://github.com/tmux/tmux/releases/download/$TMUX_VERSION/tmux-$TMUX_VERSION.tar.gz
if [[ 0 -ne $? ]]; then
  echo "download tmux failed"
  exit 1
fi

if [[ -e "tmux-$TMUX_VERSION" ]]; then
  rm -rf "tmux-$TMUX_VERSION"
fi
tar -axvf tmux-$TMUX_VERSION.tar.gz

if [[ ! -e "tmux-$TMUX_VERSION" ]]; then
  echo "unpack tmux failed"
  exit 1
fi

NCURSES_HEADER="$(find $BUILD_PREBUILT_DEP/include -name curses.h)"

cd tmux-$TMUX_VERSION
if [[ -e "$BUILD_PREBUILT_DEP/lib/pkgconfig/ncursesw.pc" ]]; then
  TMUX_NCURSES_CFLAGS="$(pkg-config --cflags $BUILD_PREBUILT_DEP/lib/pkgconfig/ncursesw.pc)"
  TMUX_NCURSES_LINK="$(pkg-config --libs $BUILD_PREBUILT_DEP/lib/pkgconfig/ncursesw.pc)"
else
  TMUX_NCURSES_CFLAGS="$(pkg-config --cflags $BUILD_PREBUILT_DEP/lib/pkgconfig/ncurses.pc)"
  TMUX_NCURSES_LINK="$(pkg-config --libs $BUILD_PREBUILT_DEP/lib/pkgconfig/ncurses.pc)"
fi

env LDFLAGS="-L$BUILD_PREBUILT_DEP/lib" CFLAGS="-I$BUILD_PREBUILT_DEP/include" \
./configure --prefix="$BUILD_PREBUILT_TMUX" \
--enable-static --enable-utf8proc \
PKG_CONFIG_PATH="$PKG_CONFIG_PATH" \
LIBNCURSES_CFLAGS="$TMUX_NCURSES_CFLAGS" \
LIBNCURSES_LIBS="$TMUX_NCURSES_LINK" \
LIBEVENT_CFLAGS="$(pkg-config --cflags $BUILD_PREBUILT_DEP/lib/pkgconfig/libevent.pc)" \
LIBEVENT_LIBS="$(pkg-config --libs $BUILD_PREBUILT_DEP/lib/pkgconfig/libevent.pc)"

make -j4
make install
if [[ 0 -ne $? ]]; then
  echo "build tmux failed"
  exit 1
fi

# pack tmux
cd "$BUILD_DIR/prebuilt"
tar -zcvf tmux-$TMUX_VERSION.musl-bin.tar.gz tmux
cd "$BUILD_DIR"

mv -f "$BUILD_DIR/prebuilt/tmux-$TMUX_VERSION.musl-bin.tar.gz" ./
echo "all jobs done."
