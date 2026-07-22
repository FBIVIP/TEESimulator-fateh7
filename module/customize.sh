MIN_SDK=29
CONFIG_DIR=/data/misc/the_next

if [ "$BOOTMODE" != true ]; then
  abort "! Install from Magisk/KernelSU Manager only"
fi

VERSION=$(grep_prop version "${MODPATH}/module.prop")
ui_print "- Installing integrityfateh7 $VERSION"
ui_print "  STRONG (TEE) + DEVICE/BASIC (PIF)"
ui_print ""

case "$ARCH" in
  arm64) ABI_DIR="arm64-v8a" ;;
  arm)   ABI_DIR="armeabi-v7a" ;;
  x64)   ABI_DIR="x86_64" ;;
  x86)   ABI_DIR="x86" ;;
  *)     abort "! Unsupported arch: $ARCH" ;;
esac
ui_print "- ABI: $ABI_DIR | SDK: $API"
[ "$API" -lt "$MIN_SDK" ] && abort "! Min SDK $MIN_SDK required"

# --- TEE libs: move current ABI to root, drop the rest ---
if [ -d "$MODPATH/lib/$ABI_DIR" ]; then
  mv "$MODPATH/lib/$ABI_DIR/libintegrityfateh7.so" "$MODPATH/libintegrityfateh7.so"
  mv "$MODPATH/lib/$ABI_DIR/libinject.so"          "$MODPATH/inject"
fi
rm -rf "$MODPATH/lib"
chmod 755 "$MODPATH/daemon" "$MODPATH/inject" 2>/dev/null
ui_print "- TEE binaries installed"

# --- TEE config (keybox in hidden path) ---
mkdir -p "$CONFIG_DIR"
[ -f "$CONFIG_DIR/keybox.xml" ] || cp "$MODPATH/keybox.xml" "$CONFIG_DIR/keybox.xml"
[ -f "$CONFIG_DIR/target.txt" ] || cp "$MODPATH/target.txt" "$CONFIG_DIR/target.txt"
chmod 644 "$CONFIG_DIR/keybox.xml" "$CONFIG_DIR/target.txt" 2>/dev/null
ui_print "- Keybox path: $CONFIG_DIR (replace keybox.xml for STRONG)"

# --- PIF setup (DEVICE/BASIC via zygisk) ---
if [ -d "$MODPATH/zygisk" ]; then
  ui_print "- Setting up PIF (fingerprint spoofing)"
  if magisk --denylist status 2>/dev/null; then
    magisk --denylist rm com.google.android.gms 2>/dev/null
    magisk --denylist rm com.android.vending 2>/dev/null
  fi
  [ -f "$MODPATH/common_func.sh" ]  && . "$MODPATH/common_func.sh"
  [ -f "$MODPATH/common_setup.sh" ] && . "$MODPATH/common_setup.sh"
fi

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/daemon" 0 0 0755
set_perm "$MODPATH/inject"  0 0 0755
ui_print ""
ui_print "- Done. Reboot, then tap Action to refresh fingerprint."
