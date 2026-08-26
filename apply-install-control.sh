#!/sbin/sh

CONFIG="/sdcard/install-control.json"
USER_FILE="/data/system/users/0.xml"
BACKUP_FILE="/data/system/users/0.xml.install-control-backup"
TEMP_FILE="/data/local/tmp/user-0.install-control.xml"
PACKAGE_FILE="/data/system/users/0/package-restrictions.xml"
PACKAGE_BACKUP="/data/system/users/0/package-restrictions.xml.install-control-backup"
PACKAGE_TEMP="/data/local/tmp/package-restrictions.install-control.xml"

fail() {
    echo "ERROR: $1"
    exit 1
}

[ -f "$CONFIG" ] || fail "Missing $CONFIG"
[ -f "$USER_FILE" ] || fail "Missing $USER_FILE. Is /data mounted and decrypted?"
[ -f "$PACKAGE_FILE" ] || fail "Missing $PACKAGE_FILE"

NORMALIZED=`tr -d '[:space:]' < "$CONFIG"`
INSTALL=`echo "$NORMALIZED" | sed -n 's/.*"install":\([01]\).*/\1/p'`
HIDE_STORE=`echo "$NORMALIZED" | sed -n 's/.*"hideStore":\([01]\).*/\1/p'`
BROWSER_OFF=`echo "$NORMALIZED" | sed -n 's/.*"browserOff":\([01]\).*/\1/p'`
MUSIC_OFF=`echo "$NORMALIZED" | sed -n 's/.*"musicOff":\([01]\).*/\1/p'`
READER_OFF=`echo "$NORMALIZED" | sed -n 's/.*"readerOff":\([01]\).*/\1/p'`
UPDATER_OFF=`echo "$NORMALIZED" | sed -n 's/.*"updaterOff":\([01]\).*/\1/p'`
WALLET_OFF=`echo "$NORMALIZED" | sed -n 's/.*"walletOff":\([01]\).*/\1/p'`
EMAIL_OFF=`echo "$NORMALIZED" | sed -n 's/.*"emailOff":\([01]\).*/\1/p'`
GLOBAL_SIM_OFF=`echo "$NORMALIZED" | sed -n 's/.*"globalSimOff":\([01]\).*/\1/p'`
VIP_ACCOUNT_OFF=`echo "$NORMALIZED" | sed -n 's/.*"vipAccountOff":\([01]\).*/\1/p'`

[ -n "$INSTALL" ] && [ -n "$HIDE_STORE" ] && [ -n "$BROWSER_OFF" ] || fail "Missing install, hideStore, or browserOff"
[ -n "$MUSIC_OFF" ] && [ -n "$READER_OFF" ] && [ -n "$UPDATER_OFF" ] || fail "Missing musicOff, readerOff, or updaterOff"
[ -n "$WALLET_OFF" ] && [ -n "$EMAIL_OFF" ] || fail "Missing walletOff or emailOff"
[ -n "$GLOBAL_SIM_OFF" ] && [ -n "$VIP_ACCOUNT_OFF" ] || fail "Missing globalSimOff or vipAccountOff"

cp -p "$USER_FILE" "$BACKUP_FILE" || fail "Could not create backup"
cp -p "$USER_FILE" "$TEMP_FILE" || fail "Could not create temporary file"

# Remove only this tool's restrictions and preserve all unrelated user settings.
sed -i 's/ no_install_apps="true"//g; s/ no_install_unknown_sources="true"//g' "$TEMP_FILE" || fail "Could not update XML"

if [ "$INSTALL" = "0" ]; then
    grep -q '<restrictions' "$TEMP_FILE" || fail "Restrictions element not found"
    sed -i 's#<restrictions#<restrictions no_install_apps="true" no_install_unknown_sources="true"#' "$TEMP_FILE" || fail "Could not lock installation"
fi

grep -q '<user ' "$TEMP_FILE" || fail "Updated XML failed validation"
cp "$TEMP_FILE" "$USER_FILE" || fail "Could not write user configuration"
chown system:system "$USER_FILE"
chmod 600 "$USER_FILE"
restorecon "$USER_FILE" 2>/dev/null
rm -f "$TEMP_FILE"

cp -p "$PACKAGE_FILE" "$PACKAGE_BACKUP" || fail "Could not back up package state"
cp -p "$PACKAGE_FILE" "$PACKAGE_TEMP" || fail "Could not copy package state"

toggle_component() {
    PKG="$1"
    COMPONENT="$2"
    OFF="$3"
    awk -v pkg="$PKG" -v component="$COMPONENT" -v off="$OFF" '
        index($0, "<pkg name=\"" pkg "\"") {
            in_pkg = 1
            if (off == "1" && $0 ~ /\/>/) {
                sub(/ \/>$/, ">")
                print
                print "        <disabled-components>"
                print "            <item name=\"" component "\" />"
                print "        </disabled-components>"
                print "    </pkg>"
                in_pkg = 0
                next
            }
            print
            next
        }
        in_pkg && index($0, "<item name=\"" component "\" />") { next }
        in_pkg && /<disabled-components>/ {
            print
            if (off == "1") print "            <item name=\"" component "\" />"
            has_disabled = 1
            next
        }
        in_pkg && /<\/pkg>/ {
            if (off == "1" && has_disabled != 1) {
                print "        <disabled-components>"
                print "            <item name=\"" component "\" />"
                print "        </disabled-components>"
            }
            print
            in_pkg = 0
            has_disabled = 0
            next
        }
        { print }
    ' "$PACKAGE_TEMP" > "$PACKAGE_TEMP.new" || fail "Could not update $PKG/$COMPONENT"
    mv "$PACKAGE_TEMP.new" "$PACKAGE_TEMP" || fail "Could not finalize $PKG/$COMPONENT"
}

toggle_component "com.android.browser" "com.android.browser.BrowserActivity" "$BROWSER_OFF"
toggle_component "com.xiaomi.market" "com.xiaomi.market.ui.MarketTabActivity" "$HIDE_STORE"
toggle_component "com.miui.player" "com.miui.player.ui.MusicBrowserActivity" "$MUSIC_OFF"
toggle_component "com.duokan.reader" "com.duokan.reader.DkReaderActivity" "$READER_OFF"
toggle_component "com.mipay.wallet" "com.mipay.wallet.ui.MipayEntryActivity" "$WALLET_OFF"
toggle_component "com.android.email" "com.android.email.activity.Welcome" "$EMAIL_OFF"
toggle_component "com.miui.virtualsim" "com.miui.virtualsim.ui.MainActivity" "$GLOBAL_SIM_OFF"
toggle_component "com.xiaomi.vipaccount" "com.xiaomi.vipaccount.ui.home.dynamic.HomeFrameActivity" "$VIP_ACCOUNT_OFF"

toggle_component "com.android.updater" "com.android.updater.MainActivity" "$UPDATER_OFF"
toggle_component "com.android.updater" "com.android.updater.UpdateSettingActivity" "$UPDATER_OFF"
toggle_component "com.android.updater" "com.android.updater.receiver.BootCompletedReceiver" "$UPDATER_OFF"
toggle_component "com.android.updater" "com.android.updater.receiver.DailyCheckReceiver" "$UPDATER_OFF"
toggle_component "com.android.updater" "com.android.updater.receiver.AccountChangedReceiver" "$UPDATER_OFF"
toggle_component "com.android.updater" "com.android.updater.push.UpdaterPushReceiver" "$UPDATER_OFF"
toggle_component "com.android.updater" "com.xiaomi.push.service.receivers.NetworkStatusReceiver" "$UPDATER_OFF"
toggle_component "com.android.updater" "com.xiaomi.push.service.receivers.PingReceiver" "$UPDATER_OFF"

grep -q 'name="com.xiaomi.market"' "$PACKAGE_TEMP" || fail "Market package failed validation"
grep -q 'name="com.android.browser"' "$PACKAGE_TEMP" || fail "Browser package failed validation"
grep -q 'name="com.miui.player"' "$PACKAGE_TEMP" || fail "Music package failed validation"
grep -q 'name="com.duokan.reader"' "$PACKAGE_TEMP" || fail "Reader package failed validation"
grep -q 'name="com.android.updater"' "$PACKAGE_TEMP" || fail "Updater package failed validation"
grep -q 'name="com.mipay.wallet"' "$PACKAGE_TEMP" || fail "Wallet package failed validation"
grep -q 'name="com.android.email"' "$PACKAGE_TEMP" || fail "Email package failed validation"
grep -q 'name="com.miui.virtualsim"' "$PACKAGE_TEMP" || fail "Global SIM package failed validation"
grep -q 'name="com.xiaomi.vipaccount"' "$PACKAGE_TEMP" || fail "VIP account package failed validation"
cp "$PACKAGE_TEMP" "$PACKAGE_FILE" || fail "Could not write package state"
chown system:system "$PACKAGE_FILE"
chmod 660 "$PACKAGE_FILE"
restorecon "$PACKAGE_FILE" 2>/dev/null
rm -f "$PACKAGE_TEMP"

echo "OK: install=$INSTALL hideStore=$HIDE_STORE browserOff=$BROWSER_OFF"
echo "    musicOff=$MUSIC_OFF readerOff=$READER_OFF updaterOff=$UPDATER_OFF"
echo "    walletOff=$WALLET_OFF emailOff=$EMAIL_OFF globalSimOff=$GLOBAL_SIM_OFF"
echo "    vipAccountOff=$VIP_ACCOUNT_OFF"
echo "Reboot Android now."
