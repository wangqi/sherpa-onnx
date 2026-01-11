#!/usr/bin/env bash
#
# Build sherpa-onnx for Mac Catalyst (arm64 + x86_64)
#
set -e

dir=build-maccatalyst
mkdir -p $dir
cd $dir

# Verify onnxruntime is available (downloaded by build-ios.sh)
if [ ! -d "../build-ios/ios-onnxruntime/onnxruntime.xcframework" ]; then
    echo "Error: onnxruntime.xcframework not found."
    echo "Please run build-ios.sh first to download onnxruntime."
    exit 1
fi

# Use macOS slice of onnxruntime for Mac Catalyst
# Mac Catalyst links against macOS libraries
export SHERPA_ONNXRUNTIME_LIB_DIR=$PWD/../build-ios/ios-onnxruntime/onnxruntime.xcframework/macos-arm64_x86_64
export SHERPA_ONNXRUNTIME_INCLUDE_DIR=$PWD/../build-ios/ios-onnxruntime/onnxruntime.xcframework/Headers

echo "SHERPA_ONNXRUNTIME_LIB_DIR: $SHERPA_ONNXRUNTIME_LIB_DIR"
echo "SHERPA_ONNXRUNTIME_INCLUDE_DIR: $SHERPA_ONNXRUNTIME_INCLUDE_DIR"

# Common CMake options
CMAKE_COMMON_OPTS=(
  -DBUILD_PIPER_PHONMIZE_EXE=OFF
  -DBUILD_PIPER_PHONMIZE_TESTS=OFF
  -DBUILD_ESPEAK_NG_EXE=OFF
  -DBUILD_ESPEAK_NG_TESTS=OFF
  -DCMAKE_TOOLCHAIN_FILE=./toolchains/ios.toolchain.cmake
  -DENABLE_BITCODE=0
  -DENABLE_ARC=1
  -DENABLE_VISIBILITY=0
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_INSTALL_PREFIX=./install
  -DBUILD_SHARED_LIBS=OFF
  -DSHERPA_ONNX_ENABLE_PYTHON=OFF
  -DSHERPA_ONNX_ENABLE_TESTS=OFF
  -DSHERPA_ONNX_ENABLE_CHECK=OFF
  -DSHERPA_ONNX_ENABLE_PORTAUDIO=OFF
  -DSHERPA_ONNX_ENABLE_JNI=OFF
  -DSHERPA_ONNX_ENABLE_C_API=ON
  -DSHERPA_ONNX_ENABLE_WEBSOCKET=OFF
  -DSHERPA_ONNX_ENABLE_BINARY=OFF
  -DDEPLOYMENT_TARGET=14.0
)

echo "Building for Mac Catalyst (arm64)..."
cmake \
  "${CMAKE_COMMON_OPTS[@]}" \
  -S .. \
  -DPLATFORM=MAC_CATALYST_ARM64 \
  -B build/catalyst_arm64

cmake --build build/catalyst_arm64 -j 4

echo "Building for Mac Catalyst (x86_64)..."
cmake \
  "${CMAKE_COMMON_OPTS[@]}" \
  -S .. \
  -DPLATFORM=MAC_CATALYST \
  -B build/catalyst_x86_64

cmake --build build/catalyst_x86_64 -j 4

# Generate headers from arm64 build
cmake --build build/catalyst_arm64 --target install

echo "Combining architectures with lipo..."
mkdir -p "build/catalyst/lib"

# Library list matching build-ios.sh
LIBS=(
  libkaldi-native-fbank-core.a
  libkissfft-float.a
  libsherpa-onnx-c-api.a
  libsherpa-onnx-core.a
  libsherpa-onnx-fstfar.a
  libssentencepiece_core.a
  libsherpa-onnx-fst.a
  libsherpa-onnx-kaldifst-core.a
  libkaldi-decoder-core.a
  libucd.a
  libpiper_phonemize.a
  libespeak-ng.a
)

for f in "${LIBS[@]}"; do
  echo "  Combining $f..."
  lipo -create \
    build/catalyst_arm64/lib/${f} \
    build/catalyst_x86_64/lib/${f} \
    -output build/catalyst/lib/${f}
done

echo "Merging into single static library..."
libtool -static -o build/catalyst/libsherpa-onnx.a \
  build/catalyst/lib/libkaldi-native-fbank-core.a \
  build/catalyst/lib/libkissfft-float.a \
  build/catalyst/lib/libsherpa-onnx-c-api.a \
  build/catalyst/lib/libsherpa-onnx-core.a \
  build/catalyst/lib/libsherpa-onnx-fstfar.a \
  build/catalyst/lib/libsherpa-onnx-fst.a \
  build/catalyst/lib/libsherpa-onnx-kaldifst-core.a \
  build/catalyst/lib/libkaldi-decoder-core.a \
  build/catalyst/lib/libucd.a \
  build/catalyst/lib/libpiper_phonemize.a \
  build/catalyst/lib/libespeak-ng.a \
  build/catalyst/lib/libssentencepiece_core.a

echo "Creating xcframework for Mac Catalyst..."
rm -rf sherpa-onnx.xcframework

# Create the xcframework directory structure manually
mkdir -p sherpa-onnx.xcframework/maccatalyst-arm64_x86_64

# Copy the universal library
cp build/catalyst/libsherpa-onnx.a sherpa-onnx.xcframework/maccatalyst-arm64_x86_64/

# Copy headers
cp -r install/include sherpa-onnx.xcframework/maccatalyst-arm64_x86_64/Headers

# Create Info.plist
cat > sherpa-onnx.xcframework/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>AvailableLibraries</key>
    <array>
        <dict>
            <key>LibraryIdentifier</key>
            <string>maccatalyst-arm64_x86_64</string>
            <key>LibraryPath</key>
            <string>libsherpa-onnx.a</string>
            <key>HeadersPath</key>
            <string>Headers</string>
            <key>SupportedArchitectures</key>
            <array>
                <string>arm64</string>
                <string>x86_64</string>
            </array>
            <key>SupportedPlatform</key>
            <string>maccatalyst</string>
        </dict>
    </array>
    <key>CFBundlePackageType</key>
    <string>XFWK</string>
    <key>XCFrameworkFormatVersion</key>
    <string>1.0</string>
</dict>
</plist>
EOF

echo ""
echo "Mac Catalyst build complete!"
echo "Output: build-maccatalyst/sherpa-onnx.xcframework"
