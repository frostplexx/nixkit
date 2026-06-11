{
  lib,
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "mac-mouse-fix";
  version = "3.0.8";

  src = fetchFromGitHub {
    owner = "noah-nuebling";
    repo = "mac-mouse-fix";
    tag = finalAttrs.version;
    hash = "sha256-+YETgkmSb1eiAj88Y9wFTQ2eiFxsuFEjkFZYeXjra5k=";
    fetchSubmodules = false;
  };

  __noChroot = true;

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild

    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
    if [ ! -d "$DEVELOPER_DIR" ]; then
      echo "ERROR: system Xcode not found at $DEVELOPER_DIR." >&2
      echo "       Install Xcode from the App Store (xcodebuild is required to build from source)." >&2
      exit 1
    fi

    export HOME="$TMPDIR/build-home"
    export CFFIXED_USER_HOME="$HOME"
    mkdir -p "$HOME/Library/Caches"

        unset CC CXX CPP LD AS AR NM RANLIB STRIP OBJCOPY SIZE STRINGS LIPO \
          CFLAGS CXXFLAGS CPPFLAGS LDFLAGS ASFLAGS HOST_CC HOST_CXX \
          NIX_CFLAGS_COMPILE NIX_CFLAGS_LINK NIX_LDFLAGS NIX_CC NIX_BINTOOLS
    export PATH="$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin:$DEVELOPER_DIR/usr/bin:$PATH"

    for ent in "App/SupportFiles/App.entitlements" "Helper/SupportFiles/Helper.entitlements"; do
      /usr/libexec/PlistBuddy -c "Delete :keychain-access-groups" "$ent" 2>/dev/null || true
      /usr/libexec/PlistBuddy -c "Delete :com.apple.security.cs.disable-library-validation" "$ent" 2>/dev/null || true
      /usr/libexec/PlistBuddy -c "Add :com.apple.security.cs.disable-library-validation bool true" "$ent"
    done

    if [ -f Localization/Code/UpdateStrings/script.py ]; then
      echo 'import sys; sys.exit(0)' > Localization/Code/UpdateStrings/script.py
    fi

    echo "==> Building Mac Mouse Fix.app (ad-hoc signed)"
    /usr/bin/xcodebuild \
      -IDEPackageSupportDisableManifestSandbox=1 \
      -IDEPackageSupportDisablePluginExecutionSandbox=1 \
      -project "Mouse Fix.xcodeproj" \
      -scheme "App - Release" \
      -configuration Release \
      -derivedDataPath "$TMPDIR/DerivedData" \
      -clonedSourcePackagesDirPath "$TMPDIR/spm" \
      -packageCachePath "$TMPDIR/spm-cache" \
      ARCHS=arm64 \
      ONLY_ACTIVE_ARCH=YES \
      CLANG_MODULE_CACHE_PATH="$TMPDIR/ModuleCache" \
      CODE_SIGN_IDENTITY=- \
      CODE_SIGN_STYLE=Manual \
      DEVELOPMENT_TEAM= \
      PROVISIONING_PROFILE_SPECIFIER= \
      CODE_SIGNING_REQUIRED=NO \
      CODE_SIGNING_ALLOWED=YES \
      build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    APP="$TMPDIR/DerivedData/Build/Products/Release/Mac Mouse Fix.app"
    if [ ! -d "$APP" ]; then
      echo "ERROR: build product not found at $APP" >&2
      ls -la "$TMPDIR/DerivedData/Build/Products/Release/" 2>/dev/null || true
      exit 1
    fi

    mkdir -p "$out/Applications"
    cp -R "$APP" "$out/Applications/Mac Mouse Fix.app"

    runHook postInstall
  '';

  dontFixup = true;

  meta = {
    description = "Make your $10 mouse better than an Apple Trackpad (built from source)";
    homepage = "https://github.com/noah-nuebling/mac-mouse-fix";
    license = lib.licenses.mit; # MMF License — MIT-style with a no-rebrand clause
    platforms = ["aarch64-darwin"];
    sourceProvenance = [lib.sourceTypes.fromSource];
    mainProgram = "Mac Mouse Fix";
    maintainers = [];
  };
})
