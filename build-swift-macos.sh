#!/usr/bin/env  bash

set -ex

# Upstream v2.0.0 replaced this script with build-macos.sh, which emits a SherpaOnnxC.framework
# xcframework. The fork keeps build-swift-macos.sh because build-xcframework.sh merges its
# library + Headers slice (macos-arm64_x86_64/libsherpa-onnx.a) and wraps its libonnxruntime.a
# (onnxruntime 1.28.2 via cmake/onnxruntime-osx-universal-static.cmake) into the onnxruntime
# xcframework's macOS slice. # wangqi modified 2026-10-24

dir=build-swift-macos

# Clean existing build directory to avoid stale CMake cache issues # wangqi modified 2026-10-24
if [ -d "$dir" ]; then
  echo "Cleaning existing build directory..."
  rm -rf "$dir"
fi

mkdir -p $dir
cd $dir

# Get the correct macOS SDK path from Xcode (passed as CMAKE_OSX_SYSROOT) # wangqi modified 2026-10-24
MACOS_SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)
echo "Using macOS SDK: $MACOS_SDK_PATH"

cmake \
  -DSHERPA_ONNX_ENABLE_BINARY=OFF \
  -DSHERPA_ONNX_BUILD_C_API_EXAMPLES=OFF \
  -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
  -DCMAKE_OSX_SYSROOT="$MACOS_SDK_PATH" \
  -DCMAKE_INSTALL_PREFIX=./install \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DSHERPA_ONNX_ENABLE_PYTHON=OFF \
  -DSHERPA_ONNX_ENABLE_TESTS=OFF \
  -DSHERPA_ONNX_ENABLE_CHECK=OFF \
  -DSHERPA_ONNX_ENABLE_PORTAUDIO=OFF \
  -DSHERPA_ONNX_ENABLE_JNI=OFF \
  -DSHERPA_ONNX_ENABLE_C_API=ON \
  -DSHERPA_ONNX_ENABLE_WEBSOCKET=OFF \
  ../

make -j4
make install
rm -fv ./install/include/cargs.h

# v2.0.0 library set: espeak-ng, piper-phonemize and ucd are gone (#4055); utf8proc is new.
# Same list as upstream build-macos.sh. # wangqi modified 2026-10-24
libtool -static -o ./install/lib/libsherpa-onnx.a \
  ./install/lib/libsherpa-onnx-c-api.a \
  ./install/lib/libsherpa-onnx-core.a \
  ./install/lib/libkaldi-native-fbank-core.a \
  ./install/lib/libkissfft-float.a \
  ./install/lib/libsherpa-onnx-fstfar.a \
  ./install/lib/libsherpa-onnx-fst.a \
  ./install/lib/libsherpa-onnx-kaldifst-core.a \
  ./install/lib/libkaldi-decoder-core.a \
  ./install/lib/libssentencepiece_core.a \
  ./install/lib/libutf8proc.a

xcodebuild -create-xcframework \
  -library install/lib/libsherpa-onnx.a \
  -headers install/include \
  -output sherpa-onnx.xcframework
