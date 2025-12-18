#!/system/bin/sh
MODDIR=${0%/*}

while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 1
done

if [ -f "$MODDIR/system/system_ext/priv-app/KaoriosToolbox/KaoriosToolbox.apk" ]; then
    pm install -r "$MODDIR/system/system_ext/priv-app/KaoriosToolbox/KaoriosToolbox.apk" >/dev/null 2>&1
fi
