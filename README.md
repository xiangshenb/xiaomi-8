# 小米 8 SE MIUI 10 功能机控制工具

用于小米 8 SE（代号 `sirius`）MIUI 10 / Android 9 的应用安装与系统应用入口控制。工具通过临时启动 TWRP，修改 `/data/system` 中的用户配置实现限制，不删除系统 APK。

适用的已验证环境：MIUI `V10.3.2.0.PEBCNXM`、Android 9（SDK 28）、Bootloader 已解锁、可启动 TWRP。

## 功能

- 禁止或允许应用安装，包括应用商店、未知来源 APK 与 `adb install`
- 隐藏或显示小米应用商店入口
- 关闭或启用系统浏览器、小米音乐、多看阅读
- 关闭或启用系统更新、小米钱包、电子邮件、全球上网和“我的小米”入口
- 每次应用前备份被修改的用户配置，支持恢复

## 使用前准备

1. 解锁 Bootloader。
2. 使用数据线连接设备，并确保设备可进入 Fastboot。
3. 根据设备实际情况准备可用的 `twrp.img`。仓库已包含当前设备使用的镜像。
4. 编辑 `install-control.json`，所有字段都必须保留，值只能为 `0` 或 `1`。

当前仓库默认配置为允许安装应用，同时关闭浏览器、音乐、阅读、系统更新、钱包、电子邮件、全球上网和“我的小米”入口。

## Windows 操作

双击 `install-control.cmd`，或在本目录执行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install-control.ps1 apply
```

脚本会重启手机至 Fastboot、临时启动 TWRP、推送配置和应用脚本、执行修改，然后重启 Android 并验证结果。

查看已连接设备的当前限制状态：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install-control.ps1 status
```

快速切换安装权限并应用配置：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install-control.ps1 enable
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install-control.ps1 disable
```

## 配置说明

`install-control.json` 示例：

```json
{"install":1,"hideStore":0,"browserOff":1,"musicOff":1,"readerOff":1,"updaterOff":1,"walletOff":1,"emailOff":1,"globalSimOff":1,"vipAccountOff":1}
```

| 字段 | `0` | `1` |
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

## TWRP 内操作

在 TWRP 的“高级 > 终端”中，可以运行已推送到手机存储的快捷脚本：

```sh
# 全部限制
sh /sdcard/lock.sh

# 全部恢复
sh /sdcard/unlock.sh

# 仅允许安装，保留其他限制
sh /sdcard/install.sh
```

执行后请在 TWRP 中选择“重启 > 系统”。

## 注意事项

- 请先备份重要数据，并确认设备型号、系统版本和 TWRP 兼容性；错误修改 `/data/system` 可能导致系统无法启动。
- 不要禁用或删除 `com.miui.packageinstaller`，这会导致当前验证环境无法正常进入 Android。
- 不要删除 `com.xiaomi.market`。本工具只隐藏其桌面入口，以避免破坏系统依赖。
- 修改操作会在 `/data/system/users/` 下创建 `.install-control-backup` 备份文件；异常时可参考 [`MIUI10功能机配置方案.md`](MIUI10功能机配置方案.md) 中的手工恢复步骤。

## 文件说明

- `install-control.ps1`: Windows 主控制脚本
- `apply-install-control.sh`: 在 TWRP 中执行配置的脚本
- `install-control.json`: 控制开关配置
- `lock.sh`、`unlock.sh`、`install.sh`: 手机端 TWRP 快捷脚本
- `MIUI10功能机配置方案.md`: 实现原理、完整操作记录和故障恢复说明
- `adb.exe`、`fastboot.exe`: Android Platform Tools 二进制文件及相关依赖

## 第三方组件

仓库包含 Android Platform Tools，其版权和许可声明位于 `NOTICE.txt`。
