#!/usr/bin/env bash
#
# Script to merge iOS and macOS xcframeworks into a unified xcframework
# that supports all Apple platforms (iOS devices, iOS simulators, and macOS)
#
# Usage: ./build-xcframework.sh
#
# Prerequisites:
#   - Run ./build-ios.sh first to generate iOS xcframework
#   - Run ./build-swift-macos.sh first to generate macOS xcframework
#
# Output:
#   - build-apple/sherpa-onnx.xcframework

set -e

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
  echo "[ERROR] $1" >&2
  exit 1
}

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if required source xcframeworks exist
check_prerequisites() {
  log "Checking prerequisites..."
  
  if [ ! -d "build-ios/sherpa-onnx.xcframework" ]; then
    error "iOS xcframework not found at build-ios/sherpa-onnx.xcframework. Please run ./build-ios.sh first."
  fi
  
  if [ ! -d "build-swift-macos/sherpa-onnx.xcframework" ]; then
    error "macOS xcframework not found at build-swift-macos/sherpa-onnx.xcframework. Please run ./build-swift-macos.sh first."
  fi
  
  log "✅ Prerequisites check passed"
}

# Clean and prepare output directory
prepare_output_dir() {
  log "Preparing output directory..."
  
  # Remove existing build-apple directory if it exists
  if [ -d "build-apple" ]; then
    log "Removing existing build-apple directory..."
    rm -rf build-apple
  fi
  
  # Create fresh build-apple directory
  mkdir -p build-apple
  log "✅ Output directory prepared"
}

# Extract library paths from xcframework
get_library_paths() {
  local xcframework_path=$1
  local platform=$2
  
  if [ "$platform" = "ios" ]; then
    # For iOS device
    echo "$xcframework_path/ios-arm64"
  elif [ "$platform" = "ios-simulator" ]; then
    # For iOS simulator
    echo "$xcframework_path/ios-arm64_x86_64-simulator"
  elif [ "$platform" = "macos" ]; then
    # For macOS
    echo "$xcframework_path/macos-arm64_x86_64"
  fi
}

# Create the unified xcframework
create_unified_xcframework() {
  log "Creating unified xcframework..."
  
  # Get library paths from each xcframework
  local ios_device_path=$(get_library_paths "build-ios/sherpa-onnx.xcframework" "ios")
  local ios_sim_path=$(get_library_paths "build-ios/sherpa-onnx.xcframework" "ios-simulator")
  local macos_path=$(get_library_paths "build-swift-macos/sherpa-onnx.xcframework" "macos")
  
  # Verify paths exist
  if [ ! -d "$ios_device_path" ]; then
    error "iOS device library not found at $ios_device_path"
  fi
  if [ ! -d "$ios_sim_path" ]; then
    error "iOS simulator library not found at $ios_sim_path"
  fi
  if [ ! -d "$macos_path" ]; then
    error "macOS library not found at $macos_path"
  fi
  
  # Resolve static libraries and headers for each slice
  local ios_device_lib="$ios_device_path/libsherpa-onnx.a"
  local ios_sim_lib="$ios_sim_path/libsherpa-onnx.a"
  local macos_lib="$macos_path/libsherpa-onnx.a"
  local ios_device_headers="$ios_device_path/Headers"
  local ios_sim_headers="$ios_sim_path/Headers"
  local macos_headers="$macos_path/Headers"

  for lib in "$ios_device_lib" "$ios_sim_lib" "$macos_lib"; do
    if [ ! -f "$lib" ]; then
      error "Expected static library not found: $lib"
    fi
  done
  for hdr in "$ios_device_headers" "$ios_sim_headers" "$macos_headers"; do
    if [ ! -d "$hdr" ]; then
      error "Expected Headers folder not found: $hdr"
    fi
  done

  # Build the xcodebuild command with all libraries
  local xcodebuild_cmd="xcodebuild -create-xcframework"
  xcodebuild_cmd="$xcodebuild_cmd -library $ios_device_lib -headers $ios_device_headers"
  xcodebuild_cmd="$xcodebuild_cmd -library $ios_sim_lib -headers $ios_sim_headers"
  xcodebuild_cmd="$xcodebuild_cmd -library $macos_lib -headers $macos_headers"
  
  # Set output path
  xcodebuild_cmd="$xcodebuild_cmd -output build-apple/sherpa-onnx.xcframework"
  
  # Execute the command
  log "Executing: $xcodebuild_cmd"
  eval $xcodebuild_cmd
  
  if [ $? -eq 0 ]; then
    log "✅ Successfully created unified xcframework"
  else
    error "Failed to create unified xcframework"
  fi
}

# Verify the created xcframework
verify_xcframework() {
  log "Verifying unified xcframework..."
  
  local xcframework_path="build-apple/sherpa-onnx.xcframework"
  
  if [ ! -d "$xcframework_path" ]; then
    error "Unified xcframework not found at $xcframework_path"
  fi
  
  # Check Info.plist exists
  if [ ! -f "$xcframework_path/Info.plist" ]; then
    error "Info.plist not found in xcframework"
  fi
  
  # List available architectures
  log "Available architectures in unified xcframework:"
  
  # Parse Info.plist to show supported platforms
  /usr/libexec/PlistBuddy -c "Print :AvailableLibraries" "$xcframework_path/Info.plist" 2>/dev/null | grep -A 2 "SupportedPlatform" | grep -v "^--$" || true
  
  # Check each platform directory
  local platforms=("ios-arm64" "ios-arm64_x86_64-simulator" "macos-arm64_x86_64")
  for platform in "${platforms[@]}"; do
    if [ -d "$xcframework_path/$platform" ]; then
      echo -e "${GREEN}✅ Found platform: $platform${NC}"
      
      # Verify library structure
      local lib_path="$xcframework_path/$platform"
      if [ -f "$lib_path/libsherpa-onnx.a" ] || [ -f "$lib_path/sherpa-onnx.a" ]; then
        echo "   - Static library exists"
        # Show library size
        local lib_file=$(find "$lib_path" -name "*.a" | head -n1)
        if [ -f "$lib_file" ]; then
          local size=$(ls -lh "$lib_file" | awk '{print $5}')
          echo "   - Library size: $size"
        fi
      fi
      if [ -d "$lib_path/Headers" ]; then
        local header_count=$(find "$lib_path/Headers" -name "*.h" | wc -l)
        echo "   - Headers exist ($header_count header files)"
      fi
    else
      echo -e "${YELLOW}⚠️  Platform not found: $platform${NC}"
    fi
  done
  
  log "✅ Verification complete"
}

# Display usage information
show_usage_info() {
  echo ""
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}✅ Unified XCFramework Created Successfully!${NC}"
  echo -e "${GREEN}========================================${NC}"
  echo ""
  echo "📦 Location: build-apple/sherpa-onnx.xcframework"
  echo ""
  echo "📱 Supported Platforms:"
  echo "   • iOS (arm64) - Physical devices"
  echo "   • iOS Simulator (arm64, x86_64)"
  echo "   • macOS (arm64, x86_64)"
  echo ""
  echo "🔧 Usage in Xcode:"
  echo "   1. Drag and drop build-apple/sherpa-onnx.xcframework into your Xcode project"
  echo "   2. Make sure to select 'Copy items if needed'"
  echo "   3. Add to your target's 'Frameworks, Libraries, and Embedded Content'"
  echo "   4. Set to 'Embed & Sign'"
  echo ""
  echo "📝 Swift Package Manager:"
  echo "   .binaryTarget("
  echo "       name: \"sherpa-onnx\","
  echo "       path: \"build-apple/sherpa-onnx.xcframework\""
  echo "   )"
  echo ""
}

# Main execution
main() {
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}Sherpa-ONNX XCFramework Merger${NC}"
  echo -e "${GREEN}========================================${NC}"
  echo ""
  
  # Step 1: Check prerequisites
  check_prerequisites
  
  # Step 2: Prepare output directory
  prepare_output_dir
  
  # Step 3: Create unified xcframework
  create_unified_xcframework
  
  # Step 4: Verify the result
  verify_xcframework
  
  # Step 5: Show usage information
  show_usage_info
}

# Run main function
main "$@"
