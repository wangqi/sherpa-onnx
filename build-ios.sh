#!/usr/bin/env  bash

set -e

dir=build-ios
mkdir -p $dir
cd $dir
# Upstream v2.0.0 onnxruntime version (1.28.2) and download source; the fork keeps its pinned
# SDK / compiler paths and the ~/Downloads local copy below.
onnxruntime_version=${SHERPA_ONNX_ONNXRUNTIME_VERSION:-1.28.2}
onnxruntime_dir=ios-onnxruntime/$onnxruntime_version

# Pin the iOS SDKs and compilers explicitly so a non-default Xcode or a stray toolchain on PATH
# cannot leak into the cross build. # wangqi modified 2026-10-24
IOS_DEVICE_SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)
IOS_SIM_SDK_PATH=$(xcrun --sdk iphonesimulator --show-sdk-path)
IOS_SIM_CLANG=$(xcrun --sdk iphonesimulator --find clang)
IOS_SIM_CLANGXX=$(xcrun --sdk iphonesimulator --find clang++)
IOS_DEVICE_CLANG=$(xcrun --sdk iphoneos --find clang)
IOS_DEVICE_CLANGXX=$(xcrun --sdk iphoneos --find clang++)
IOS_LIBTOOL=$(xcrun --find libtool)

if [ ! -d "$IOS_DEVICE_SDK_PATH" ] || [ ! -d "$IOS_SIM_SDK_PATH" ] || \
   [ ! -x "$IOS_SIM_CLANG" ] || [ ! -x "$IOS_SIM_CLANGXX" ] || \
   [ ! -x "$IOS_DEVICE_CLANG" ] || [ ! -x "$IOS_DEVICE_CLANGXX" ] || \
   [ ! -x "$IOS_LIBTOOL" ]; then
  echo "Unable to locate required iOS SDK or compiler paths."
  echo "Device SDK: $IOS_DEVICE_SDK_PATH"
  echo "Simulator SDK: $IOS_SIM_SDK_PATH"
  echo "Simulator clang: $IOS_SIM_CLANG"
  echo "Simulator clang++: $IOS_SIM_CLANGXX"
  echo "Device clang: $IOS_DEVICE_CLANG"
  echo "Device clang++: $IOS_DEVICE_CLANGXX"
  echo "libtool: $IOS_LIBTOOL"
  exit 1
fi

export LIBTOOL=$IOS_LIBTOOL

if [ ! -f $onnxruntime_dir/onnxruntime.xcframework/ios-arm64/onnxruntime.framework/onnxruntime ]; then
  mkdir -p $onnxruntime_dir
  # Prefer a pre-downloaded local copy in ~/Downloads (avoids re-downloading on clean builds). # wangqi modified 2026-10-24
  LOCAL_DOWNLOAD="$HOME/Downloads/onnxruntime-ios-static-xcframework-${onnxruntime_version}/onnxruntime.xcframework"
  if [ -d "$LOCAL_DOWNLOAD" ]; then
    echo "Copying onnxruntime xcframework from $LOCAL_DOWNLOAD"
    cp -r "$LOCAL_DOWNLOAD" "$onnxruntime_dir/onnxruntime.xcframework"
  else
    pushd $onnxruntime_dir
    wget -c https://github.com/csukuangfj/onnxruntime-libs/releases/download/v${onnxruntime_version}/onnxruntime-ios-static-xcframework-${onnxruntime_version}.xcframework.zip
    unzip -o onnxruntime-ios-static-xcframework-${onnxruntime_version}.xcframework.zip
    rm onnxruntime-ios-static-xcframework-${onnxruntime_version}.xcframework.zip
    popd
  fi
fi

# Always refresh the unversioned link with -n so a link left by an older version is replaced,
# not written through. The exports below use the versioned path. # wangqi modified 2026-10-24
ln -sfn $onnxruntime_version/onnxruntime.xcframework ios-onnxruntime/onnxruntime.xcframework
XCF="$PWD/$onnxruntime_dir/onnxruntime.xcframework"

# First, for simulator
echo "Building for simulator (x86_64)"

export SHERPA_ONNXRUNTIME_LIB_DIR=$XCF/ios-arm64_x86_64-simulator
export SHERPA_ONNXRUNTIME_INCLUDE_DIR=$XCF/ios-arm64_x86_64-simulator/onnxruntime.framework/Headers

echo "SHERPA_ONNXRUNTIME_LIB_DIR: $SHERPA_ONNXRUNTIME_LIB_DIR"
echo "SHERPA_ONNXRUNTIME_INCLUDE_DIR $SHERPA_ONNXRUNTIME_INCLUDE_DIR"

# Note: We use -DENABLE_ARC=1 here to fix the linking error:
#
# The symbol _NSLog is not defined
#

# Explicit sysroot and compilers from the pinned SDK paths above. # wangqi modified 2026-10-24
cmake \
  -S .. \
  -DCMAKE_TOOLCHAIN_FILE=./toolchains/ios.toolchain.cmake \
  -DCMAKE_OSX_SYSROOT=$IOS_SIM_SDK_PATH \
  -DCMAKE_C_COMPILER=$IOS_SIM_CLANG \
  -DCMAKE_CXX_COMPILER=$IOS_SIM_CLANGXX \
  -DPLATFORM=SIMULATOR64 \
  -DENABLE_BITCODE=0 \
  -DENABLE_ARC=1 \
  -DENABLE_VISIBILITY=0 \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DSHERPA_ONNX_ENABLE_PYTHON=OFF \
  -DSHERPA_ONNX_ENABLE_BINARY=OFF \
  -DSHERPA_ONNX_ENABLE_TESTS=OFF \
  -DSHERPA_ONNX_ENABLE_CHECK=OFF \
  -DSHERPA_ONNX_ENABLE_PORTAUDIO=OFF \
  -DSHERPA_ONNX_ENABLE_JNI=OFF \
  -DSHERPA_ONNX_ENABLE_C_API=ON \
  -DSHERPA_ONNX_ENABLE_WEBSOCKET=OFF \
  -DDEPLOYMENT_TARGET=13.0 \
  -B build/simulator_x86_64

cmake --build build/simulator_x86_64 -j 4

echo "Building for simulator (arm64)"

# Explicit sysroot and compilers from the pinned SDK paths above. # wangqi modified 2026-10-24
cmake \
  -S .. \
  -DCMAKE_TOOLCHAIN_FILE=./toolchains/ios.toolchain.cmake \
  -DCMAKE_OSX_SYSROOT=$IOS_SIM_SDK_PATH \
  -DCMAKE_C_COMPILER=$IOS_SIM_CLANG \
  -DCMAKE_CXX_COMPILER=$IOS_SIM_CLANGXX \
  -DPLATFORM=SIMULATORARM64 \
  -DENABLE_BITCODE=0 \
  -DENABLE_ARC=1 \
  -DENABLE_VISIBILITY=0 \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=./install \
  -DBUILD_SHARED_LIBS=OFF \
  -DSHERPA_ONNX_ENABLE_PYTHON=OFF \
  -DSHERPA_ONNX_ENABLE_BINARY=OFF \
  -DSHERPA_ONNX_ENABLE_TESTS=OFF \
  -DSHERPA_ONNX_ENABLE_CHECK=OFF \
  -DSHERPA_ONNX_ENABLE_PORTAUDIO=OFF \
  -DSHERPA_ONNX_ENABLE_JNI=OFF \
  -DSHERPA_ONNX_ENABLE_C_API=ON \
  -DSHERPA_ONNX_ENABLE_WEBSOCKET=OFF \
  -DDEPLOYMENT_TARGET=13.0 \
  -B build/simulator_arm64

cmake --build build/simulator_arm64 -j 4

echo "Building for arm64"

export SHERPA_ONNXRUNTIME_LIB_DIR=$XCF/ios-arm64
export SHERPA_ONNXRUNTIME_INCLUDE_DIR=$XCF/ios-arm64/onnxruntime.framework/Headers

# Explicit sysroot and compilers from the pinned SDK paths above. # wangqi modified 2026-10-24
cmake \
  -S .. \
  -DCMAKE_TOOLCHAIN_FILE=./toolchains/ios.toolchain.cmake \
  -DCMAKE_OSX_SYSROOT=$IOS_DEVICE_SDK_PATH \
  -DCMAKE_C_COMPILER=$IOS_DEVICE_CLANG \
  -DCMAKE_CXX_COMPILER=$IOS_DEVICE_CLANGXX \
  -DPLATFORM=OS64 \
  -DENABLE_BITCODE=0 \
  -DENABLE_ARC=1 \
  -DENABLE_VISIBILITY=0 \
  -DCMAKE_INSTALL_PREFIX=./install \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DSHERPA_ONNX_ENABLE_PYTHON=OFF \
  -DSHERPA_ONNX_ENABLE_BINARY=OFF \
  -DSHERPA_ONNX_ENABLE_TESTS=OFF \
  -DSHERPA_ONNX_ENABLE_CHECK=OFF \
  -DSHERPA_ONNX_ENABLE_PORTAUDIO=OFF \
  -DSHERPA_ONNX_ENABLE_JNI=OFF \
  -DSHERPA_ONNX_ENABLE_C_API=ON \
  -DSHERPA_ONNX_ENABLE_WEBSOCKET=OFF \
  -DDEPLOYMENT_TARGET=13.0 \
  -B build/os64

cmake --build build/os64 -j 4
# Generate headers for sherpa-onnx.xcframework
cmake --build build/os64 --target install

echo "Generate xcframework"

mkdir -p "build/simulator/lib"
for f in libkaldi-native-fbank-core.a libkissfft-float.a libsherpa-onnx-c-api.a libsherpa-onnx-core.a \
         libsherpa-onnx-fstfar.a libssentencepiece_core.a libutf8proc.a \
         libsherpa-onnx-fst.a libsherpa-onnx-kaldifst-core.a libkaldi-decoder-core.a; do
  lipo -create build/simulator_arm64/lib/${f} \
               build/simulator_x86_64/lib/${f} \
       -output build/simulator/lib/${f}
done

# Merge archive first, because the following xcodebuild create xcframework
# cannot accept multi archive with the same architecture.
libtool -static -o build/simulator/libsherpa-onnx.a \
  build/simulator/lib/libkaldi-native-fbank-core.a \
  build/simulator/lib/libkissfft-float.a \
  build/simulator/lib/libsherpa-onnx-c-api.a \
  build/simulator/lib/libsherpa-onnx-core.a  \
  build/simulator/lib/libsherpa-onnx-fstfar.a   \
  build/simulator/lib/libsherpa-onnx-fst.a   \
  build/simulator/lib/libsherpa-onnx-kaldifst-core.a \
  build/simulator/lib/libkaldi-decoder-core.a \
  build/simulator/lib/libssentencepiece_core.a \
  build/simulator/lib/libutf8proc.a

libtool -static -o build/os64/libsherpa-onnx.a \
  build/os64/lib/libkaldi-native-fbank-core.a \
  build/os64/lib/libkissfft-float.a \
  build/os64/lib/libsherpa-onnx-c-api.a \
  build/os64/lib/libsherpa-onnx-core.a \
  build/os64/lib/libsherpa-onnx-fstfar.a   \
  build/os64/lib/libsherpa-onnx-fst.a   \
  build/os64/lib/libsherpa-onnx-kaldifst-core.a \
  build/os64/lib/libkaldi-decoder-core.a \
  build/os64/lib/libssentencepiece_core.a \
  build/os64/lib/libutf8proc.a

# The fork keeps the library + Headers xcframework layout (libsherpa-onnx.a, Headers/sherpa-onnx/c-api)
# instead of upstream's SherpaOnnxC.framework bundles: build-xcframework.sh merges these slices with
# the macOS and Mac Catalyst ones, and sherpa-onnx_swift reads ios-arm64/Headers/sherpa-onnx through
# its CSherpaOnnx symlink. # wangqi modified 2026-10-24
rm -rf sherpa-onnx.xcframework

xcodebuild -create-xcframework \
      -library "build/os64/libsherpa-onnx.a" -headers install/include \
      -library "build/simulator/libsherpa-onnx.a" -headers install/include  \
      -output sherpa-onnx.xcframework
