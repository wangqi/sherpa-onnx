#!/usr/bin/env bash
#
# Script to build iOS and macOS libraries and merge them into a unified xcframework
# that supports all Apple platforms (iOS devices, iOS simulators, and macOS)
#
# Usage: ./build-xcframework.sh [options]
#
# Options:
#   --skip-ios      Skip iOS build (use existing build-ios/sherpa-onnx.xcframework)
#   --skip-macos    Skip macOS build (use existing build-swift-macos/sherpa-onnx.xcframework)
#   --skip-build    Skip both builds (only merge existing xcframeworks)
#   --clean         Clean all build directories before building
#   -h, --help      Show this help message
#
# Output:
#   - build-apple/sherpa-onnx.xcframework

set -e

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default options
SKIP_IOS=false
SKIP_MACOS=false
CLEAN_BUILD=false

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_step() {
  echo -e "${BLUE}[STEP]${NC} $1"
}

error() {
  echo -e "${RED}[ERROR]${NC} $1" >&2
  exit 1
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

success() {
  echo -e "${GREEN}[OK]${NC} $1"
}

# Show help message
show_help() {
  echo "Usage: ./build-xcframework.sh [options]"
  echo ""
  echo "Build sherpa-onnx xcframework for all Apple platforms."
  echo ""
  echo "Options:"
  echo "  --skip-ios      Skip iOS build (use existing build)"
  echo "  --skip-macos    Skip macOS build (use existing build)"
  echo "  --skip-build    Skip both builds (only merge existing xcframeworks)"
  echo "  --clean         Clean all build directories before building"
  echo "  -h, --help      Show this help message"
  echo ""
  echo "Output:"
  echo "  build-apple/sherpa-onnx.xcframework"
  echo ""
  echo "Examples:"
  echo "  ./build-xcframework.sh              # Full build"
  echo "  ./build-xcframework.sh --clean      # Clean and rebuild everything"
  echo "  ./build-xcframework.sh --skip-ios   # Only rebuild macOS"
  echo "  ./build-xcframework.sh --skip-build # Only merge existing builds"
}

# Parse command line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --skip-ios)
        SKIP_IOS=true
        shift
        ;;
      --skip-macos)
        SKIP_MACOS=true
        shift
        ;;
      --skip-build)
        SKIP_IOS=true
        SKIP_MACOS=true
        shift
        ;;
      --clean)
        CLEAN_BUILD=true
        shift
        ;;
      -h|--help)
        show_help
        exit 0
        ;;
      *)
        error "Unknown option: $1. Use --help for usage information."
        ;;
    esac
  done
}

# Clean build directories
clean_builds() {
  log_step "Cleaning build directories..."

  if [ -d "build-ios" ]; then
    log "Removing build-ios..."
    rm -rf build-ios
  fi

  if [ -d "build-swift-macos" ]; then
    log "Removing build-swift-macos..."
    rm -rf build-swift-macos
  fi

  if [ -d "build-apple" ]; then
    log "Removing build-apple..."
    rm -rf build-apple
  fi

  success "Build directories cleaned"
}

# Build iOS xcframework
build_ios() {
  if [ "$SKIP_IOS" = true ]; then
    log_step "Skipping iOS build (--skip-ios specified)"
    if [ ! -d "build-ios/sherpa-onnx.xcframework" ]; then
      error "iOS xcframework not found at build-ios/sherpa-onnx.xcframework. Cannot skip iOS build."
    fi
    return 0
  fi

  log_step "Building iOS xcframework..."
  echo ""

  # Check if build script exists
  if [ ! -f "./build-ios.sh" ]; then
    error "build-ios.sh not found in current directory"
  fi

  # Run the iOS build
  local start_time=$(date +%s)

  if ./build-ios.sh; then
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    success "iOS build completed in ${duration}s"
  else
    error "iOS build failed. Check the output above for details."
  fi

  # Verify the output
  if [ ! -d "build-ios/sherpa-onnx.xcframework" ]; then
    error "iOS xcframework not found after build. Build may have failed silently."
  fi
}

# Build macOS xcframework
build_macos() {
  if [ "$SKIP_MACOS" = true ]; then
    log_step "Skipping macOS build (--skip-macos specified)"
    if [ ! -d "build-swift-macos/sherpa-onnx.xcframework" ]; then
      error "macOS xcframework not found at build-swift-macos/sherpa-onnx.xcframework. Cannot skip macOS build."
    fi
    return 0
  fi

  log_step "Building macOS xcframework..."
  echo ""

  # Check if build script exists
  if [ ! -f "./build-swift-macos.sh" ]; then
    error "build-swift-macos.sh not found in current directory"
  fi

  # Run the macOS build
  local start_time=$(date +%s)

  if ./build-swift-macos.sh; then
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    success "macOS build completed in ${duration}s"
  else
    error "macOS build failed. Check the output above for details."
  fi

  # Verify the output
  if [ ! -d "build-swift-macos/sherpa-onnx.xcframework" ]; then
    error "macOS xcframework not found after build. Build may have failed silently."
  fi
}

# Check if required source xcframeworks exist
check_prerequisites() {
  log_step "Checking prerequisites..."

  if [ ! -d "build-ios/sherpa-onnx.xcframework" ]; then
    error "iOS xcframework not found at build-ios/sherpa-onnx.xcframework"
  fi

  if [ ! -d "build-swift-macos/sherpa-onnx.xcframework" ]; then
    error "macOS xcframework not found at build-swift-macos/sherpa-onnx.xcframework"
  fi

  success "Prerequisites check passed"
}

# Clean and prepare output directory
prepare_output_dir() {
  log_step "Preparing output directory..."

  # Remove existing build-apple directory if it exists
  if [ -d "build-apple" ]; then
    log "Removing existing build-apple directory..."
    rm -rf build-apple
  fi

  # Create fresh build-apple directory
  mkdir -p build-apple
  success "Output directory prepared"
}

# Extract library paths from xcframework
get_library_paths() {
  local xcframework_path=$1
  local platform=$2

  if [ "$platform" = "ios" ]; then
    echo "$xcframework_path/ios-arm64"
  elif [ "$platform" = "ios-simulator" ]; then
    echo "$xcframework_path/ios-arm64_x86_64-simulator"
  elif [ "$platform" = "macos" ]; then
    echo "$xcframework_path/macos-arm64_x86_64"
  fi
}

# Create the unified xcframework
create_unified_xcframework() {
  log_step "Creating unified xcframework..."

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
  if eval $xcodebuild_cmd; then
    success "Successfully created unified xcframework"
  else
    error "Failed to create unified xcframework"
  fi
}

# Verify the created xcframework
verify_xcframework() {
  log_step "Verifying unified xcframework..."

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
      echo -e "${GREEN}  [OK] $platform${NC}"

      # Verify library structure
      local lib_path="$xcframework_path/$platform"
      if [ -f "$lib_path/libsherpa-onnx.a" ] || [ -f "$lib_path/sherpa-onnx.a" ]; then
        # Show library size
        local lib_file=$(find "$lib_path" -name "*.a" | head -n1)
        if [ -f "$lib_file" ]; then
          local size=$(ls -lh "$lib_file" | awk '{print $5}')
          echo "       Library: $size"
        fi
      fi
      if [ -d "$lib_path/Headers" ]; then
        local header_count=$(find "$lib_path/Headers" -name "*.h" | wc -l | tr -d ' ')
        echo "       Headers: $header_count files"
      fi
    else
      echo -e "${YELLOW}  [MISSING] $platform${NC}"
    fi
  done

  success "Verification complete"
}

# Display usage information
show_usage_info() {
  echo ""
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}  Build Complete!${NC}"
  echo -e "${GREEN}========================================${NC}"
  echo ""
  echo "Output: build-apple/sherpa-onnx.xcframework"
  echo ""
  echo "Supported Platforms:"
  echo "  - iOS (arm64) - Physical devices"
  echo "  - iOS Simulator (arm64, x86_64)"
  echo "  - macOS (arm64, x86_64)"
  echo ""
  echo "Usage in Xcode:"
  echo "  1. Drag build-apple/sherpa-onnx.xcframework into your project"
  echo "  2. Select 'Copy items if needed'"
  echo "  3. Add to 'Frameworks, Libraries, and Embedded Content'"
  echo ""
  echo "Swift Package Manager:"
  echo "  .binaryTarget("
  echo "      name: \"sherpa-onnx\","
  echo "      path: \"build-apple/sherpa-onnx.xcframework\""
  echo "  )"
  echo ""
}

# Main execution
main() {
  local total_start_time=$(date +%s)

  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}  Sherpa-ONNX XCFramework Builder${NC}"
  echo -e "${GREEN}========================================${NC}"
  echo ""

  # Parse command line arguments
  parse_args "$@"

  # Show build configuration
  log "Build configuration:"
  echo "  - iOS build:   $([ "$SKIP_IOS" = true ] && echo "SKIP" || echo "BUILD")"
  echo "  - macOS build: $([ "$SKIP_MACOS" = true ] && echo "SKIP" || echo "BUILD")"
  echo "  - Clean build: $([ "$CLEAN_BUILD" = true ] && echo "YES" || echo "NO")"
  echo ""

  # Step 0: Clean if requested
  if [ "$CLEAN_BUILD" = true ]; then
    clean_builds
    echo ""
  fi

  # Step 1: Build iOS
  build_ios
  echo ""

  # Step 2: Build macOS
  build_macos
  echo ""

  # Step 3: Check prerequisites (verify both builds exist)
  check_prerequisites
  echo ""

  # Step 4: Prepare output directory
  prepare_output_dir
  echo ""

  # Step 5: Create unified xcframework
  create_unified_xcframework
  echo ""

  # Step 6: Verify the result
  verify_xcframework

  # Calculate total time
  local total_end_time=$(date +%s)
  local total_duration=$((total_end_time - total_start_time))
  local minutes=$((total_duration / 60))
  local seconds=$((total_duration % 60))

  echo ""
  log "Total build time: ${minutes}m ${seconds}s"

  # Step 7: Show usage information
  show_usage_info
}

# Run main function
main "$@"
