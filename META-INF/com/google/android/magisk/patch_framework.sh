#!/sbin/sh
# Kaorios Framework Patcher - Dynamic Installer module
# Patches framework.jar for Play Integrity, Pixel Spoofing, GPhotos

# Configuration
KAORIOS_REPO="Wuang26/Kaorios-Toolbox"
KAORIOS_API_URL="https://api.github.com/repos/$KAORIOS_REPO/releases/latest"
FW_WORK_DIR="$TMP/framework_workspace"
KAORIOS_WORK_DIR="$TMP/kaorios_download"
UTILS_DIR="$KAORIOS_WORK_DIR/utils"
DEX_EXTRACT_DIR="$KAORIOS_WORK_DIR/dex_extract"
KAORIOS_CACHE_DIR="/data/local/tmp/kaorios_cache"
KAORIOS_VERSION_FILE="$KAORIOS_CACHE_DIR/version.txt"
FRAMEWORK_SRC="/system/framework/framework.jar"
FRAMEWORK_JAR="$TMP/framework.jar"
FRAMEWORK_PATCHED="$TMP/framework_patched.jar"

get_last_smali_dir() {
    local decompile_dir="$1"
    local target_smali_dir="smali"
    local max_num=0
    for dir in "$decompile_dir"/smali_classes*; do
        if [ -d "$dir" ]; then
            local num=$(basename "$dir" | sed 's/smali_classes//')
            if echo "$num" | grep -qE '^[0-9]+$' && [ "$num" -gt "$max_num" ]; then
                max_num=$num
                target_smali_dir="smali_classes${num}"
            fi
        fi
    done
    echo "$target_smali_dir"
}

# Extract framework.jar
ui_print "- Extracting framework.jar..."
if [ ! -f "$FRAMEWORK_SRC" ]; then
    ui_print "! ERROR: framework.jar not found"
    return 1
fi
cp "$FRAMEWORK_SRC" "$FRAMEWORK_JAR" || { ui_print "! Failed to copy framework.jar"; return 1; }

# Download Kaorios components
ui_print "- Fetching Kaorios components..."
download_kaorios_components() {
    mkdir -p "$KAORIOS_WORK_DIR" "$UTILS_DIR" "$KAORIOS_CACHE_DIR"
    local release_info="$KAORIOS_WORK_DIR/release.json"

    if command -v curl >/dev/null 2>&1; then
        curl -sL "$KAORIOS_API_URL" > "$release_info"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$release_info" "$KAORIOS_API_URL"
    else
        ui_print "! Neither curl nor wget available"
        return 1
    fi

    [ ! -f "$release_info" ] || [ ! -s "$release_info" ] && { ui_print "! Failed to fetch release info"; return 1; }

    local latest_version=$(grep -o '"tag_name": *"[^"]*"' "$release_info" | head -1 | sed 's/"tag_name": *"\(.*\)"/\1/')
    local cached_version=""
    [ -f "$KAORIOS_VERSION_FILE" ] && cached_version=$(cat "$KAORIOS_VERSION_FILE")

    local cache_valid=true
    [ ! -f "$KAORIOS_CACHE_DIR/KaoriosToolbox.apk" ] || \
    [ ! -f "$KAORIOS_CACHE_DIR/privapp_whitelist_com.kousei.kaorios.xml" ] || \
    [ ! -f "$KAORIOS_CACHE_DIR/classes.dex" ] && cache_valid=false

    if [ "$cached_version" = "$latest_version" ] && [ "$cache_valid" = "true" ]; then
        ui_print "  Using cached $cached_version"
        cp "$KAORIOS_CACHE_DIR/KaoriosToolbox.apk" "$KAORIOS_WORK_DIR/"
        cp "$KAORIOS_CACHE_DIR/privapp_whitelist_com.kousei.kaorios.xml" "$KAORIOS_WORK_DIR/"
        cp "$KAORIOS_CACHE_DIR/classes.dex" "$KAORIOS_WORK_DIR/"
        return 0
    fi

    local apk_url=$(grep -o '"browser_download_url": *"[^"]*KaoriosToolbox[^"]*\.apk"' "$release_info" | head -1 | sed 's/"browser_download_url": *"\(.*\)"/\1/')
    [ -z "$apk_url" ] && apk_url=$(grep -o '"browser_download_url": *"[^"]*Kaorios-Toolbox[^"]*\.apk"' "$release_info" | head -1 | sed 's/"browser_download_url": *"\(.*\)"/\1/')
    local xml_url=$(grep -o '"browser_download_url": *"[^"]*privapp_whitelist[^"]*\.xml"' "$release_info" | head -1 | sed 's/"browser_download_url": *"\(.*\)"/\1/')
    local dex_url=$(grep -o '"browser_download_url": *"[^"]*classes[^"]*\.dex"' "$release_info" | head -1 | sed 's/"browser_download_url": *"\(.*\)"/\1/')

    [ -z "$apk_url" ] || [ -z "$xml_url" ] || [ -z "$dex_url" ] && { ui_print "! Missing release assets"; return 1; }

    ui_print "  Downloading $latest_version..."
    if command -v curl >/dev/null 2>&1; then
        curl -sL -o "$KAORIOS_CACHE_DIR/KaoriosToolbox.apk" "$apk_url"
        curl -sL -o "$KAORIOS_CACHE_DIR/privapp_whitelist_com.kousei.kaorios.xml" "$xml_url"
        curl -sL -o "$KAORIOS_CACHE_DIR/classes.dex" "$dex_url"
    else
        wget -q -O "$KAORIOS_CACHE_DIR/KaoriosToolbox.apk" "$apk_url"
        wget -q -O "$KAORIOS_CACHE_DIR/privapp_whitelist_com.kousei.kaorios.xml" "$xml_url"
        wget -q -O "$KAORIOS_CACHE_DIR/classes.dex" "$dex_url"
    fi

    echo "$latest_version" > "$KAORIOS_VERSION_FILE"
    cp "$KAORIOS_CACHE_DIR/KaoriosToolbox.apk" "$KAORIOS_WORK_DIR/"
    cp "$KAORIOS_CACHE_DIR/privapp_whitelist_com.kousei.kaorios.xml" "$KAORIOS_WORK_DIR/"
    cp "$KAORIOS_CACHE_DIR/classes.dex" "$KAORIOS_WORK_DIR/"
    return 0
}
download_kaorios_components || return 1

# Extract utility classes
ui_print "- Extracting utility classes..."
extract_utility_classes() {
    mkdir -p "$DEX_EXTRACT_DIR/smali"
    local dex_path="$KAORIOS_WORK_DIR/classes.dex"
    local baksmali_jar=""
    # Search for baksmali - $TMP/baksmali.jar is extracted by customize.sh
    for jar in "$TMP/baksmali.jar" "$l/baksmali.jar" "$TMP/zbin/baksmali.jar" "$TMP/zbin/ugu/baksmali.jar"; do
        [ -f "$jar" ] && { baksmali_jar="$jar"; break; }
    done
    [ -z "$baksmali_jar" ] && { ui_print "! baksmali.jar not found"; return 1; }

    run_jar "$baksmali_jar" d "$dex_path" -o "$DEX_EXTRACT_DIR/smali" || { ui_print "! baksmali failed"; return 1; }

    local utils_source=$(find "$DEX_EXTRACT_DIR" -type d -path "*/com/android/internal/util/kaorios" 2>/dev/null | head -1)
    [ -z "$utils_source" ] || [ ! -d "$utils_source" ] && { ui_print "! Utility classes not found"; return 1; }

    cp -r "$utils_source" "$UTILS_DIR/"
    return 0
}
extract_utility_classes || return 1

# Decompile framework.jar
ui_print "- Decompiling framework.jar..."
mkdir -p "$FW_WORK_DIR"
dynamic_apktool -decompile "$FRAMEWORK_JAR" -o "$FW_WORK_DIR" -ps || { ui_print "! Decompilation failed"; return 1; }

# Inject utility classes
ui_print "- Injecting utility classes..."
inject_utility_classes() {
    local decompile_dir="$1"
    local target_smali_dir=$(get_last_smali_dir "$decompile_dir")
    local target_dir="$decompile_dir/$target_smali_dir/com/android/internal/util/kaorios"
    mkdir -p "$target_dir"
    cp -r "$UTILS_DIR/kaorios"/* "$target_dir/"
    return 0
}
inject_utility_classes "$FW_WORK_DIR" || return 1

# Apply patches
ui_print "- Applying framework patches..."

patch_apm() {
    local target_file=$(find "$FW_WORK_DIR" -type f -path "*/android/app/ApplicationPackageManager.smali" | head -1)
    [ -z "$target_file" ] && return 0

    local current_smali_dir=$(echo "$target_file" | sed -E 's|(.*/smali(_classes[0-9]*)?)/.*|\1|')
    local last_smali_dir=$(get_last_smali_dir "$FW_WORK_DIR")
    local target_root="$FW_WORK_DIR/$last_smali_dir"

    if [ "$current_smali_dir" != "$target_root" ]; then
        local new_dir="$target_root/android/app"
        mkdir -p "$new_dir"
        mv "$current_smali_dir"/android/app/ApplicationPackageManager*.smali "$new_dir/" 2>/dev/null
        target_file="$new_dir/ApplicationPackageManager.smali"
    fi

    grep -q "Lcom/android/internal/util/kaorios/KaoriFeatureOverrides" "$target_file" && return 0

    local method_start=$(grep -n "\.method.*hasSystemFeature(Ljava/lang/String;I)Z" "$target_file" | head -1 | cut -d: -f1)
    if [ -n "$method_start" ]; then
        local reg_rel_line=$(tail -n +$method_start "$target_file" | head -n 10 | grep -E -n '\.registers|\.locals' | head -1 | cut -d: -f1)
        if [ -n "$reg_rel_line" ]; then
            local actual_reg_line=$((method_start + reg_rel_line - 1))
            local block_file="$TMP/kaorios_apm_block.smali"
            cat > "$block_file" << 'KBLOCK'

    invoke-static {}, Landroid/app/ActivityThread;->currentPackageName()Ljava/lang/String;
    move-result-object v0
    iget-object v1, p0, Landroid/app/ApplicationPackageManager;->mContext:Landroid/app/ContextImpl;
    invoke-static {v1, p1, v0}, Lcom/android/internal/util/kaorios/KaoriFeatureOverrides;->getOverride(Landroid/content/Context;Ljava/lang/String;Ljava/lang/String;)Ljava/lang/Boolean;
    move-result-object v0
    if-eqz v0, :cond_kaorios_skip
    invoke-virtual {v0}, Ljava/lang/Boolean;->booleanValue()Z
    move-result p0
    return p0
    :cond_kaorios_skip

KBLOCK
            head -n $actual_reg_line "$target_file" > "${target_file}.tmp"
            cat "$block_file" >> "${target_file}.tmp"
            tail -n +$((actual_reg_line + 1)) "$target_file" >> "${target_file}.tmp"
            mv "${target_file}.tmp" "$target_file"
            rm -f "$block_file"
        fi
    fi
    return 0
}

patch_instrumentation() {
    local target_file=$(find "$FW_WORK_DIR" -type f -path "*/android/app/Instrumentation.smali" | head -1)
    [ -z "$target_file" ] && return 0
    grep -q "KaoriPropsUtils;->KaoriProps" "$target_file" && return 0

    local method1_start=$(grep -n "\.method.*static.*newApplication(Ljava/lang/Class;Landroid/content/Context;)" "$target_file" | head -1 | cut -d: -f1)
    if [ -n "$method1_start" ]; then
        local method1_end=$(tail -n +$method1_start "$target_file" | grep -n "^\.end method" | head -1 | cut -d: -f1)
        if [ -n "$method1_end" ]; then
            local return_rel=$(tail -n +$method1_start "$target_file" | head -n $method1_end | grep -n "return-object v0" | tail -1 | cut -d: -f1)
            if [ -n "$return_rel" ]; then
                local insert_at=$((method1_start + return_rel - 1))
                head -n $((insert_at - 1)) "$target_file" > "${target_file}.tmp"
                echo "    invoke-static {p1}, Lcom/android/internal/util/kaorios/KaoriPropsUtils;->KaoriProps(Landroid/content/Context;)V" >> "${target_file}.tmp"
                tail -n +$insert_at "$target_file" >> "${target_file}.tmp"
                mv "${target_file}.tmp" "$target_file"
            fi
        fi
    fi

    local method2_start=$(grep -n "\.method.*newApplication(Ljava/lang/ClassLoader;Ljava/lang/String;Landroid/content/Context;)" "$target_file" | head -1 | cut -d: -f1)
    if [ -n "$method2_start" ]; then
        local method2_end=$(tail -n +$method2_start "$target_file" | grep -n "^\.end method" | head -1 | cut -d: -f1)
        if [ -n "$method2_end" ]; then
            local return_rel=$(tail -n +$method2_start "$target_file" | head -n $method2_end | grep -n "return-object v0" | tail -1 | cut -d: -f1)
            if [ -n "$return_rel" ]; then
                local insert_at=$((method2_start + return_rel - 1))
                head -n $((insert_at - 1)) "$target_file" > "${target_file}.tmp"
                echo "    invoke-static {p3}, Lcom/android/internal/util/kaorios/KaoriPropsUtils;->KaoriProps(Landroid/content/Context;)V" >> "${target_file}.tmp"
                tail -n +$insert_at "$target_file" >> "${target_file}.tmp"
                mv "${target_file}.tmp" "$target_file"
            fi
        fi
    fi
    return 0
}

patch_keystore2() {
    local target_file=$(find "$FW_WORK_DIR" -type f -path "*/android/security/KeyStore2.smali" | head -1)
    [ -z "$target_file" ] && return 0
    grep -q "KaoriKeyboxHooks;->KaoriGetKeyEntry" "$target_file" && return 0

    local method_start=$(grep -n "\.method.*getKeyEntry(Landroid/system/keystore2/KeyDescriptor;)" "$target_file" | head -1 | cut -d: -f1)
    if [ -n "$method_start" ]; then
        local method_end=$(tail -n +$method_start "$target_file" | grep -n "^\.end method" | head -1 | cut -d: -f1)
        if [ -n "$method_end" ]; then
            local return_rel=$(tail -n +$method_start "$target_file" | head -n $method_end | grep -n "return-object v0" | tail -1 | cut -d: -f1)
            if [ -n "$return_rel" ]; then
                local insert_at=$((method_start + return_rel - 1))
                head -n $((insert_at - 1)) "$target_file" > "${target_file}.tmp"
                echo "    invoke-static {v0}, Lcom/android/internal/util/kaorios/KaoriKeyboxHooks;->KaoriGetKeyEntry(Landroid/system/keystore2/KeyEntryResponse;)Landroid/system/keystore2/KeyEntryResponse;" >> "${target_file}.tmp"
                echo "    move-result-object v0" >> "${target_file}.tmp"
                tail -n +$insert_at "$target_file" >> "${target_file}.tmp"
                mv "${target_file}.tmp" "$target_file"
            fi
        fi
    fi
    return 0
}

patch_keystore_spi() {
    local target_file=$(find "$FW_WORK_DIR" -type f -path "*/android/security/keystore2/AndroidKeyStoreSpi.smali" | head -1)
    [ -z "$target_file" ] && return 0
    grep -q "KaoriPropsUtils;->KaoriGetCertificateChain" "$target_file" && return 0

    local method_start=$(grep -n "\.method.*engineGetCertificateChain" "$target_file" | head -1 | cut -d: -f1)
    if [ -n "$method_start" ]; then
        local registers_rel=$(tail -n +$method_start "$target_file" | head -n 20 | grep -E -n '\.registers|\.locals' | head -1 | cut -d: -f1)
        if [ -n "$registers_rel" ]; then
            local insert_at=$((method_start + registers_rel))
            head -n $insert_at "$target_file" > "${target_file}.tmp"
            echo "    invoke-static {}, Lcom/android/internal/util/kaorios/KaoriPropsUtils;->KaoriGetCertificateChain()V" >> "${target_file}.tmp"
            tail -n +$((insert_at + 1)) "$target_file" >> "${target_file}.tmp"
            mv "${target_file}.tmp" "$target_file"
        fi

        local method_end=$(tail -n +$method_start "$target_file" | grep -n "^\.end method" | head -1 | cut -d: -f1)
        if [ -n "$method_end" ]; then
            local return_rel=$(tail -n +$method_start "$target_file" | head -n $method_end | grep -n "return-object v3" | head -1 | cut -d: -f1)
            if [ -n "$return_rel" ]; then
                local insert_at=$((method_start + return_rel - 1))
                head -n $((insert_at - 1)) "$target_file" > "${target_file}.tmp"
                echo "    invoke-static {v3}, Lcom/android/internal/util/kaorios/KaoriKeyboxHooks;->KaoriGetCertificateChain([Ljava/security/cert/Certificate;)[Ljava/security/cert/Certificate;" >> "${target_file}.tmp"
                echo "    move-result-object v3" >> "${target_file}.tmp"
                tail -n +$insert_at "$target_file" >> "${target_file}.tmp"
                mv "${target_file}.tmp" "$target_file"
            fi
        fi
    fi
    return 0
}

patch_apm
patch_instrumentation
patch_keystore2
patch_keystore_spi

# Recompile
ui_print "- Recompiling framework.jar..."
sync; echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
dynamic_apktool -recompile "$FW_WORK_DIR" -o "$FRAMEWORK_PATCHED" -j 2 -ps || { ui_print "! Recompilation failed"; return 1; }

# Install to module
ui_print "- Installing to module..."
mkdir -p "$MODPATH/system/framework"
cp "$FRAMEWORK_PATCHED" "$MODPATH/system/framework/framework.jar" || { ui_print "! Failed to install framework.jar"; return 1; }

# Install extras
if [ -f "$KAORIOS_WORK_DIR/KaoriosToolbox.apk" ]; then
    mkdir -p "$MODPATH/system/system_ext/priv-app/KaoriosToolbox"
    cp "$KAORIOS_WORK_DIR/KaoriosToolbox.apk" "$MODPATH/system/system_ext/priv-app/KaoriosToolbox/"
    mkdir -p "$TMP/apk_extract"
    unzip -o -q "$KAORIOS_WORK_DIR/KaoriosToolbox.apk" "lib/*" -d "$TMP/apk_extract" 2>/dev/null
    for arch in arm64-v8a armeabi-v7a x86 x86_64; do
        arch_short=$(echo "$arch" | sed 's/arm64-v8a/arm64/;s/armeabi-v7a/arm/;s/x86_64/x86_64/;s/x86$/x86/')
        if [ -d "$TMP/apk_extract/lib/$arch" ]; then
            mkdir -p "$MODPATH/system/system_ext/priv-app/KaoriosToolbox/lib/$arch_short"
            for lib in "$TMP/apk_extract/lib/$arch"/*.so; do
                [ -f "$lib" ] && cp "$lib" "$MODPATH/system/system_ext/priv-app/KaoriosToolbox/lib/$arch_short/"
            done
        fi
    done
fi

[ -f "$KAORIOS_WORK_DIR/privapp_whitelist_com.kousei.kaorios.xml" ] && {
    mkdir -p "$MODPATH/system/system_ext/etc/permissions"
    cp "$KAORIOS_WORK_DIR/privapp_whitelist_com.kousei.kaorios.xml" "$MODPATH/system/system_ext/etc/permissions/"
}

# Cleanup download cache
ui_print "- Cleaning up..."
rm -rf "$KAORIOS_CACHE_DIR" 2>/dev/null
rm -rf "$KAORIOS_WORK_DIR" 2>/dev/null
rm -rf "$DEX_EXTRACT_DIR" 2>/dev/null
rm -rf "$FW_WORK_DIR" 2>/dev/null
rm -f "$FRAMEWORK_JAR" "$FRAMEWORK_PATCHED" 2>/dev/null

ui_print "- Patching complete. Reboot to apply."