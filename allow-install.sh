#!/sbin/sh
echo '{"install":1,"hideStore":1,"browserOff":1,"musicOff":1,"readerOff":1,"updaterOff":1,"walletOff":1,"emailOff":1,"globalSimOff":1,"vipAccountOff":1}' > /sdcard/install-control.json
sh /sdcard/apply-install-control.sh
