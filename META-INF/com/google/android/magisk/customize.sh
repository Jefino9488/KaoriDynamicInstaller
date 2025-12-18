#!/sbin/sh
# Magisk modules use $MODPATH as main path
# Your script starts here:

# Extract patch_framework.sh from the ZIP to TMP directory
PATCH_SCRIPT="$TMP/patch_framework.sh"
BAKSMALI_JAR="$TMP/baksmali.jar"

ui_print "[*] Extracting patching script..."

# Extract patch_framework.sh
unzip -qo "$ZIPFILE" "META-INF/com/google/android/magisk/patch_framework.sh" -d "$TMP" 2>/dev/null
if [ -f "$TMP/META-INF/com/google/android/magisk/patch_framework.sh" ]; then
    mv "$TMP/META-INF/com/google/android/magisk/patch_framework.sh" "$PATCH_SCRIPT"
    chmod 755 "$PATCH_SCRIPT"
else
    # Fallback to installzip
    unzip -qo "$installzip" "META-INF/com/google/android/magisk/patch_framework.sh" -d "$TMP" 2>/dev/null
    [ -f "$TMP/META-INF/com/google/android/magisk/patch_framework.sh" ] && mv "$TMP/META-INF/com/google/android/magisk/patch_framework.sh" "$PATCH_SCRIPT" && chmod 755 "$PATCH_SCRIPT"
fi

# Extract baksmali.jar
unzip -qo "$ZIPFILE" "META-INF/zbin/baksmali.jar" -d "$TMP" 2>/dev/null
if [ -f "$TMP/META-INF/zbin/baksmali.jar" ]; then
    mv "$TMP/META-INF/zbin/baksmali.jar" "$BAKSMALI_JAR"
else
    # Fallback to installzip
    unzip -qo "$installzip" "META-INF/zbin/baksmali.jar" -d "$TMP" 2>/dev/null
    [ -f "$TMP/META-INF/zbin/baksmali.jar" ] && mv "$TMP/META-INF/zbin/baksmali.jar" "$BAKSMALI_JAR"
fi

ui_print "[+] Extracted scripts"

# Source the patching script
if [ -f "$PATCH_SCRIPT" ]; then
    ui_print "[*] Running framework patcher..."
    . "$PATCH_SCRIPT"
else
    ui_print "[!] ERROR: patch_framework.sh not found!"
    return 1
fi
