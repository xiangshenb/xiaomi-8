# 小米 8 SE / MIUI 10 功能机配置方案

## 1. 设备与环境

- 设备：小米 8 SE，代号 `sirius`
- 系统：MIUI 10.3.2.0，版本 `V10.3.2.0.PEBCNXM`
- Android：Android 9，SDK 28
- Bootloader：已解锁
- Recovery：TWRP 3.7.0_9-0，已刷入 Recovery 分区，按音量上+电源键直接进入
- 已禁用 `/system/bin/install-recovery.sh`（重命名为 `.bak`），防止 MIUI 开机恢复官方 Recovery
- Android 正常系统：没有 `su`、Magisk、KernelSU 或 APatch
- TWRP Recovery：ADB shell 为 root，可修改 `/data/system` 下的系统状态文件

注意：Bootloader 解锁和 TWRP root 不等于 Android 正常系统已经 root。当前控制方案需要在 TWRP 中应用配置。

## 2. 实现目标

将手机限制为儿童使用的“功能机”，实现以下功能：

- 禁止通过小米应用商店安装应用
- 禁止通过浏览器、微信、文件管理器等来源安装 APK
- 禁止通过 ADB 安装应用
- 隐藏小米应用商店桌面入口
- 关闭系统浏览器的桌面和网页入口
- 关闭小米音乐
- 关闭多看阅读
- 关闭小米钱包
- 关闭电子邮件
- 关闭全球上网
- 关闭“我的小米”
- 彻底关闭 MIUI 系统更新的界面、自动检查和推送触发
- 所有限制均可通过一个 JSON 文件配置并恢复
- 不删除系统 APK，不禁用 MIUI 启动所依赖的关键系统包
- 已禁用 MIUI 的 `install-recovery.sh`，防止官方 Recovery 覆盖 TWRP

## 3. 文件位置

电脑端文件：

```text
G:\softWare\xiaomi\platform-tools\install-control.json
G:\softWare\xiaomi\platform-tools\apply-install-control.sh
G:\softWare\xiaomi\platform-tools\install-control.ps1
G:\softWare\xiaomi\platform-tools\install-control.cmd
G:\softWare\xiaomi\platform-tools\twrp.img
```

手机端文件：

```text
/sdcard/lock.sh      全部限制（禁止安装+隐藏所有应用）
/sdcard/unlock.sh    全部恢复（允许安装+显示所有应用）
/sdcard/install.sh   只允许安装，其他限制保持
/sdcard/a.sh         应用脚本（被上面三个调用）
```

手机端执行后自动生成：

```text
/sdcard/install-control.json       配置文件（临时）
```

## 4. JSON 配置

当前配置：

```json
{"install":0,"hideStore":1,"browserOff":1,"musicOff":1,"readerOff":1,"updaterOff":1,"walletOff":1,"emailOff":1,"globalSimOff":1,"vipAccountOff":1}
```

字段说明：

| 字段 | 值为 0 | 值为 1 |
| --- | --- | --- |
| `install` | 禁止安装应用 | 允许安装应用 |
| `hideStore` | 显示小米应用商店 | 隐藏小米应用商店 |
| `browserOff` | 启用系统浏览器 | 关闭系统浏览器 |
| `musicOff` | 启用小米音乐 | 关闭小米音乐 |
| `readerOff` | 启用多看阅读 | 关闭多看阅读 |
| `updaterOff` | 启用系统更新 | 关闭系统更新 |
| `walletOff` | 启用小米钱包 | 关闭小米钱包 |
| `emailOff` | 启用电子邮件 | 关闭电子邮件 |
| `globalSimOff` | 启用全球上网 | 关闭全球上网 |
| `vipAccountOff` | 启用“我的小米” | 关闭“我的小米” |

配置文件中的所有字段都必须保留，值只能是数字 `0` 或 `1`。

## 5. 实现原理

### 5.1 禁止安装应用

在以下 Android 用户配置文件中设置官方用户限制：

```text
/data/system/users/0.xml
```

禁止安装时写入：

```xml
<restrictions no_install_apps="true" no_install_unknown_sources="true" />
```

允许安装时，只删除这两个属性，不覆盖其他用户限制。

`no_install_apps` 在 Package Installer 创建安装会话时统一拦截安装，因此可以阻止：

- 小米应用商店安装
- 浏览器下载 APK 后安装
- 微信、QQ 等收到 APK 后安装
- 文件管理器打开 APK 安装
- 其他应用调用安装器安装
- `adb install` 安装

实测拒绝信息：

```text
Security exception: User restriction prevents installing
```

### 5.2 隐藏小米应用商店

小米应用商店包名：

```text
com.xiaomi.market
```

桌面启动 Activity：

```text
com.xiaomi.market.ui.MarketTabActivity
```

脚本只在以下文件的 `disabled-components` 中禁用该桌面 Activity：

```text
/data/system/users/0/package-restrictions.xml
```

商店包、服务和广播接收器保持启用，避免影响 MIUI 启动或其他系统依赖。

验证结果：

```text
No activity found
package:com.xiaomi.market
```

这表示商店桌面入口不可用，但商店包仍然存在并启用。

### 5.3 关闭系统浏览器

系统浏览器包名：

```text
com.android.browser
```

桌面和 HTTP/HTTPS 网页入口：

```text
com.android.browser.BrowserActivity
```

脚本只禁用 `BrowserActivity`，效果包括：

- 隐藏浏览器图标
- 阻止直接启动浏览器
- 阻止 HTTP/HTTPS 链接调用该浏览器
- 保留浏览器包和系统可能依赖的其他组件

验证结果：

```text
No activity found
No activity found
package:com.android.browser
```

### 5.4 关闭小米音乐

包名：

```text
com.miui.player
```

主入口：

```text
com.miui.player.ui.MusicBrowserActivity
```

脚本通过组件级禁用关闭音乐主入口，不删除音乐 APK。

### 5.5 关闭多看阅读

包名：

```text
com.duokan.reader
```

主入口：

```text
com.duokan.reader.DkReaderActivity
```

脚本通过组件级禁用关闭阅读主入口，不删除阅读 APK。

### 5.6 关闭系统更新

系统更新包名：

```text
com.android.updater
```

脚本关闭以下组件：

```text
com.android.updater.MainActivity
com.android.updater.UpdateSettingActivity
com.android.updater.receiver.BootCompletedReceiver
com.android.updater.receiver.DailyCheckReceiver
com.android.updater.receiver.AccountChangedReceiver
com.android.updater.push.UpdaterPushReceiver
com.xiaomi.push.service.receivers.NetworkStatusReceiver
com.xiaomi.push.service.receivers.PingReceiver
```

关闭范围包括：

- 系统更新主界面
- 系统更新设置界面
- 开机自动检查
- 每日定时检查
- 小米推送触发更新
- 网络变化触发更新
- 小米账号变化触发更新
- 更新定时器
- 自动下载更新

相关系统设置当前为：

```text
ota_disable_automatic_update=1
auto_update=0
miui_update_ready=0
```

系统更新 APK 仍保留在：

```text
/system/app/Updater/Updater.apk
```

没有删除或修改系统分区，以便日后恢复。

### 5.7 关闭小米钱包、电子邮件、全球上网和“我的小米”

对应包和主入口：

```text
小米钱包：com.mipay.wallet / com.mipay.wallet.ui.MipayEntryActivity
电子邮件：com.android.email / com.android.email.activity.Welcome
全球上网：com.miui.virtualsim / com.miui.virtualsim.ui.MainActivity
我的小米：com.xiaomi.vipaccount / com.xiaomi.vipaccount.ui.home.dynamic.HomeFrameActivity
```

`readerOff` 只控制多看阅读 `com.duokan.reader`，不控制“我的小米”。“我的小米”由 `vipAccountOff` 单独控制。

## 6. 手机端操作方法（不需要电脑）

### 6.1 进入 TWRP

TWRP 已刷入 Recovery 分区，不需要电脑。

1. 手机关机
2. 同时按住 **音量上 + 电源键**
3. 进入 TWRP 界面

### 6.2 使用快捷脚本（推荐）

在 TWRP 中点 **高级 > 终端**，执行一行命令即可：

全部限制（禁止安装 + 隐藏所有应用）：

```sh
sh /sdcard/lock.sh
```

全部恢复（允许安装 + 显示所有应用）：

```sh
sh /sdcard/unlock.sh
```

只临时允许安装，其他限制保持不变：

```sh
sh /sdcard/install.sh
```

执行成功后显示：

```text
OK: install=0 hideStore=1 browserOff=1
    musicOff=1 readerOff=1 updaterOff=1
    walletOff=1 emailOff=1 globalSimOff=1
    vipAccountOff=1
Reboot Android now.
```

然后在 TWRP 中点 **重启 > 系统**。

脚本不会自动重启，需要手动在 TWRP 主菜单点 **Reboot > System**。

### 6.3 手动编辑 JSON

如果只想改某个开关而不是全部，在 TWRP 终端用 `nano` 编辑：

```sh
nano /sdcard/install-control.json
```

JSON 内容：

```json
{"install":0,"hideStore":1,"browserOff":1,"musicOff":1,"readerOff":1,"updaterOff":1,"walletOff":1,"emailOff":1,"globalSimOff":1,"vipAccountOff":1}
```

把要改的开关值从 `0` 改成 `1` 或从 `1` 改成 `0`。

在 `nano` 中保存：

```text
Ctrl+O
回车
Ctrl+X
```

保存后必须执行脚本才能生效：

```sh
sh /sdcard/a.sh
```

然后重启系统。

注意：只改 JSON 后直接重启不会生效，必须执行 `a.sh`。

### 6.4 手机端文件列表

```text
/sdcard/lock.sh      全部限制
/sdcard/unlock.sh    全部恢复
/sdcard/install.sh   只允许安装
/sdcard/a.sh         应用脚本（被上面三个调用）
```

## 7. 电脑端操作方法

### 7.1 编辑配置

用记事本打开：

```text
G:\softWare\xiaomi\platform-tools\install-control.json
```

修改各开关值（0 或 1），保存。

### 7.2 应用配置

双击：

```text
install-control.cmd
```

脚本会自动：
1. 读取 `install-control.json` 全部 10 个开关
2. 检测手机状态（正常系统或 fastboot）
3. 临时启动 TWRP
4. 推送 JSON 和脚本到手机
5. 执行应用脚本
6. 重启系统
7. 验证最终状态

不需要选择菜单，直接按 JSON 配置执行。

### 7.3 命令行方式

应用 JSON 配置：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install-control.ps1 apply
```

只查看手机当前状态：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install-control.ps1 status
```

## 8. 自动备份

Recovery 脚本每次执行前会备份配置文件：

```text
/data/system/users/0.xml.install-control-backup
/data/system/users/0/package-restrictions.xml.install-control-backup
```

脚本只管理本方案对应的用户限制和组件条目，尽量保留其他系统及应用状态。

## 9. 手工恢复备份

如果脚本执行后出现异常，可进入 TWRP，通过终端恢复最近一次备份：

```sh
cp -p /data/system/users/0.xml.install-control-backup /data/system/users/0.xml
chown system:system /data/system/users/0.xml
chmod 600 /data/system/users/0.xml
restorecon /data/system/users/0.xml

cp -p /data/system/users/0/package-restrictions.xml.install-control-backup /data/system/users/0/package-restrictions.xml
chown system:system /data/system/users/0/package-restrictions.xml
chmod 660 /data/system/users/0/package-restrictions.xml
restorecon /data/system/users/0/package-restrictions.xml
```

然后重启系统。

## 10. 故障修复记录

曾通过以下命令禁用 MIUI 安装器：

```sh
pm disable-user --user 0 com.miui.packageinstaller
```

该操作在当前 MIUI 10.3.2.0 上导致系统重启后无法进入 Android，并自动进入 Recovery。

故障状态记录在：

```text
/data/system/users/0/package-restrictions.xml
```

异常值：

```xml
<pkg name="com.miui.packageinstaller" ... enabled="3" enabledCaller="shell:1000" />
```

在 TWRP 中将其恢复为：

```xml
<pkg name="com.miui.packageinstaller" ... enabled="1" enabledCaller="shell:1000" />
```

手机随后正常进入系统。验证状态：

```text
package:com.miui.packageinstaller
installed=true
enabled=1
sys.boot_completed=1
```

## 11. 重要注意事项

不要再次禁用或删除以下关键包：

```text
com.miui.packageinstaller
com.xiaomi.market
```

特别不要执行：

```sh
pm disable-user --user 0 com.miui.packageinstaller
```

也不要通过删除 APK、刷写 `vbmeta` 等方式实现限制。

本方案的安全原则：

- 保持 MIUI 安装器启用
- 保持应用商店包启用，只隐藏桌面入口
- 对普通系统应用采用组件级关闭，不直接删除 APK
- 使用 Android 官方 `no_install_apps` 用户限制统一禁止安装
- 所有修改均位于 `/data`，保留备份且可以恢复
- 每次修改后验证 `sys.boot_completed=1`

### 11.1 TWRP 持久化

TWRP 已刷入 Recovery 分区，并已禁用 MIUI 恢复官方 Recovery 的机制：

```text
/system/bin/install-recovery.sh -> /system/bin/install-recovery.sh.bak
```

如果以后需要恢复官方 Recovery，在 TWRP 终端执行：

```sh
mount /system
mv /system/bin/install-recovery.sh.bak /system/bin/install-recovery.sh
```

然后重启系统，MIUI 会自动恢复官方 Recovery。

## 12. 当前最终状态

当前手机配置：

```json
{"install":0,"hideStore":1,"browserOff":1,"musicOff":1,"readerOff":1,"updaterOff":1,"walletOff":1,"emailOff":1,"globalSimOff":1,"vipAccountOff":1}
```

当前效果：

- 新应用安装：禁止
- 未知来源 APK：禁止
- ADB 安装：禁止
- 小米应用商店：桌面入口隐藏，包保持启用
- 系统浏览器：桌面入口和 HTTP/HTTPS 入口关闭
- 小米音乐：主入口关闭
- 多看阅读：主入口关闭
- 系统更新：界面、自启、每日检查、推送和联网触发关闭
- 小米钱包：主入口关闭
- 电子邮件：主入口关闭
- 全球上网：主入口关闭
- “我的小米”：主入口关闭
- MIUI：启动正常

最终验证：

```text
Effective restrictions:
  no_install_apps
  no_install_unknown_sources

sys.boot_completed=1
```
