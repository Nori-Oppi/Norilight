# This script requires create-dmg to be installed from https://github.com/sindresorhus/create-dmg
# (not needed when PLAIN_DMG=1 is set)
BUILD_CONFIG=$1

fail()
{
	echo "$1" 1>&2
	exit 1
}

if [ "$BUILD_CONFIG" != "Debug" ] && [ "$BUILD_CONFIG" != "Release" ]; then
  fail "Invalid build configuration - expected 'Debug' or 'Release'"
fi

BUILD_ROOT=$PWD/build
SOURCE_ROOT=$PWD
BUILD_FOLDER=$BUILD_ROOT/build-$BUILD_CONFIG
INSTALLER_FOLDER=$BUILD_ROOT/installer-$BUILD_CONFIG

if [ -n "$CI_VERSION" ]; then
  VERSION=$CI_VERSION
else
  VERSION=`cat $SOURCE_ROOT/app/version.txt`
fi

if [ "$SIGNING_PROVIDER_SHORTNAME" == "" ]; then
  SIGNING_PROVIDER_SHORTNAME=$SIGNING_IDENTITY
fi
if [ "$SIGNING_IDENTITY" == "" ]; then
  SIGNING_IDENTITY=$SIGNING_PROVIDER_SHORTNAME
fi

[ "$SIGNING_IDENTITY" == "" ] || git diff-index --quiet HEAD -- || fail "Signed release builds must not have unstaged changes!"

echo Updating dependencies
python3 $SOURCE_ROOT/setup-deps.py

echo Cleaning output directories
rm -rf $BUILD_FOLDER
rm -rf $INSTALLER_FOLDER
mkdir $BUILD_ROOT
mkdir $BUILD_FOLDER
mkdir $INSTALLER_FOLDER

# Enable LTO for official builds. Nightlies set DISABLE_LTO=1 to build faster.
if [ "$DISABLE_LTO" != "1" ]; then
  export CFLAGS=-flto=thin
  export CXXFLAGS=-flto=thin
  export LDFLAGS=-flto=thin
fi

# USE_CCACHE=1 routes the compiler through ccache (which must be installed)
QMAKE_EXTRA_ARGS=
if [ "$USE_CCACHE" == "1" ]; then QMAKE_EXTRA_ARGS="CONFIG+=ccache"; fi

echo Configuring the project
pushd $BUILD_FOLDER
qmake $SOURCE_ROOT/moonlight-qt.pro QMAKE_APPLE_DEVICE_ARCHS="x86_64 arm64" $QMAKE_EXTRA_ARGS || fail "Qmake failed!"
popd

echo Compiling Norilight in $BUILD_CONFIG configuration
pushd $BUILD_FOLDER
make -j$(sysctl -n hw.logicalcpu) $(echo "$BUILD_CONFIG" | tr '[:upper:]' '[:lower:]') || fail "Make failed!"
popd

echo Saving dSYM file
pushd $BUILD_FOLDER
dsymutil app/Norilight.app/Contents/MacOS/Norilight -o Norilight-$VERSION.dsym || fail "dSYM creation failed!"
cp -R Norilight-$VERSION.dsym $INSTALLER_FOLDER || fail "dSYM copy failed!"
popd

echo Creating app bundle
EXTRA_ARGS=
if [ "$BUILD_CONFIG" == "Debug" ]; then EXTRA_ARGS="$EXTRA_ARGS -use-debug-libs"; fi
echo Extra deployment arguments: $EXTRA_ARGS
macdeployqt $BUILD_FOLDER/app/Norilight.app $EXTRA_ARGS -qmldir=$SOURCE_ROOT/app/gui -appstore-compliant || fail "macdeployqt failed!"

echo Removing dSYM files from app bundle
find $BUILD_FOLDER/app/Norilight.app/ -name '*.dSYM' | xargs rm -rf

if [ "$SIGNING_IDENTITY" != "" ]; then
  echo Signing app bundle
  codesign --force --deep --options runtime --timestamp --sign "$SIGNING_IDENTITY" $BUILD_FOLDER/app/Norilight.app || fail "Signing failed!"
else
  # Unsigned builds still need a valid (ad-hoc) bundle signature. macdeployqt
  # breaks the linker's per-binary signatures and leaves the bundle unsealed,
  # and macOS then silently denies Local Network access (no prompt), so mDNS
  # discovery and connecting to LAN IPs both fail. No hardened runtime here:
  # library validation would reject the ad-hoc signed frameworks.
  echo Ad-hoc signing app bundle
  codesign --force --deep --sign - $BUILD_FOLDER/app/Norilight.app || fail "Ad-hoc signing failed!"
  codesign --verify --deep --strict $BUILD_FOLDER/app/Norilight.app || fail "Ad-hoc signature verification failed!"
fi

echo Creating DMG
if [ "$PLAIN_DMG" == "1" ]; then
  # Plain DMG straight from hdiutil: no create-dmg needed and no styled window,
  # just the app next to an Applications shortcut. BUILD_FOLDER was created
  # fresh above, so the staging folder does not exist yet.
  DMG_STAGING=$BUILD_FOLDER/dmg-staging
  mkdir $DMG_STAGING
  ditto $BUILD_FOLDER/app/Norilight.app $DMG_STAGING/Norilight.app || fail "Copying the app bundle failed!"
  ln -s /Applications $DMG_STAGING/Applications
  # Build the image straight from the folder and then compress it. This is
  # about ten times faster than "hdiutil create -srcfolder", which mounts a
  # scratch image and copies the files into it.
  hdiutil makehybrid -hfs -hfs-volume-name Norilight -o $BUILD_FOLDER/Norilight-raw.dmg $DMG_STAGING || fail "hdiutil makehybrid failed!"
  hdiutil convert $BUILD_FOLDER/Norilight-raw.dmg -format ULFO -o $INSTALLER_FOLDER/Norilight.dmg || fail "hdiutil convert failed!"

  echo Verifying DMG
  DMG_MOUNT=$BUILD_FOLDER/dmg-mount
  mkdir $DMG_MOUNT
  hdiutil attach $INSTALLER_FOLDER/Norilight.dmg -readonly -nobrowse -mountpoint $DMG_MOUNT || fail "Mounting the DMG failed!"
  DMG_ERROR=
  codesign --verify --deep --strict $DMG_MOUNT/Norilight.app || DMG_ERROR="App signature in the DMG is not valid!"
  [ -x $DMG_MOUNT/Norilight.app/Contents/MacOS/Norilight ] || DMG_ERROR="App executable missing from the DMG!"
  [ "$(readlink $DMG_MOUNT/Applications)" == "/Applications" ] || DMG_ERROR="Applications shortcut missing from the DMG!"
  hdiutil detach $DMG_MOUNT || hdiutil detach -force $DMG_MOUNT
  [ "$DMG_ERROR" == "" ] || fail "$DMG_ERROR"
elif [ "$SIGNING_IDENTITY" != "" ]; then
  create-dmg $BUILD_FOLDER/app/Norilight.app $INSTALLER_FOLDER --identity="$SIGNING_IDENTITY" --no-version-in-filename || fail "create-dmg failed!"
else
  create-dmg $BUILD_FOLDER/app/Norilight.app $INSTALLER_FOLDER --no-version-in-filename
  case $? in
    0) ;;
    2) ;;
    *) fail "create-dmg failed!";;
  esac
fi

if [ "$NOTARY_KEYCHAIN_PROFILE" != "" ]; then
  echo Uploading to App Notary service
  xcrun notarytool submit --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" --wait $INSTALLER_FOLDER/Norilight.dmg || fail "Notary submission failed"

  echo Stapling notary ticket to DMG
  xcrun stapler staple -v $INSTALLER_FOLDER/Norilight.dmg || fail "Notary ticket stapling failed!"
fi

mv $INSTALLER_FOLDER/Norilight.dmg $INSTALLER_FOLDER/Norilight-$VERSION.dmg
echo Build successful