#!/usr/bin/env bash
#
# Cloud Agent install script for the FTC Robot Controller.
#
# Reproducibly provisions the Android build toolchain (SDK + NDK) that the
# Gradle build needs, then builds the debug APK. It is idempotent: every step
# is guarded so re-runs skip work that is already done, which keeps builds fast
# when the toolchain is already present (e.g. baked into an environment build
# snapshot) while still working from scratch on a plain base image.
set -eu

# Toolchain versions. The SDK platform matches compileSdkVersion and the NDK
# matches ndkVersion in build.common.gradle; bump these when that file changes.
CMDLINE_TOOLS_VERSION="13114758"
SDK_PLATFORM="platforms;android-30"
SDK_BUILD_TOOLS="build-tools;35.0.0"
SDK_NDK="ndk;21.3.6528147"

ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/android-sdk}"
SDKMANAGER="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager"

mkdir -p "$ANDROID_SDK_ROOT"

# 1. Android command-line tools (provides sdkmanager).
if [ ! -x "$SDKMANAGER" ]; then
  echo "==> Installing Android command-line tools ($CMDLINE_TOOLS_VERSION)"
  tmp_dir="$(mktemp -d)"
  curl -fsSL -o "$tmp_dir/cmdline-tools.zip" \
    "https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_VERSION}_latest.zip"
  unzip -q "$tmp_dir/cmdline-tools.zip" -d "$tmp_dir/extracted"
  rm -rf "$ANDROID_SDK_ROOT/cmdline-tools/latest"
  mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools/latest"
  mv "$tmp_dir/extracted/cmdline-tools/"* "$ANDROID_SDK_ROOT/cmdline-tools/latest/"
  rm -rf "$tmp_dir"
fi

# 2. Accept licenses and install the required SDK packages. sdkmanager is
#    idempotent and re-verifies already-installed packages quickly.
echo "==> Ensuring Android SDK packages are installed"
yes | "$SDKMANAGER" --licenses > /dev/null
"$SDKMANAGER" "platform-tools" "$SDK_PLATFORM" "$SDK_BUILD_TOOLS" "$SDK_NDK"

# 3. Point Gradle at the SDK. local.properties is gitignored / machine-specific,
#    so it is (re)written on every install rather than committed.
printf 'sdk.dir=%s\n' "$ANDROID_SDK_ROOT" > local.properties

# 4. Build the debug APK to verify the toolchain end to end.
echo "==> Building debug APK"
./gradlew --no-daemon assembleDebug
