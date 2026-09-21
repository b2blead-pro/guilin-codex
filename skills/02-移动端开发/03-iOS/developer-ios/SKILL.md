---
name: developer-ios
description: 进行 iOS、Xcode、Swift、Objective-C、CocoaPods、Swift Package Manager、iOS 工程配置、签名、证书、包名、Archive、导出 IPA 或打包排查时使用。要求开发 iOS 工程时默认遵循指定证书目录和签名密码规则。
---

# iOS 开发规范

## 设备验证顺序

- iOS 验证依次选择已连接可用真机、已在线兼容模拟器、启动已有兼容模拟器；只有没有可复用的兼容实例时才创建并启动模拟器。真机存在但签名、信任、开发者模式或安装失败时保留真实错误，不静默降级为模拟器通过。
- 通过项目既有脚本完成构建、安装、启动和测试，设备和 Runtime 自动发现，不清空应用数据，不固定设备标识。
- iOS 真机签名遵循全局 `developer-ios` skill；证书、授权失败不得伪装成无真机。

## 默认签名规则

- 开发 iOS 工程时，优先使用 `/Users/guilin/Library/Mobile Documents/com~apple~CloudDocs/Documents/ios证书/` 下按日期归档的包名、描述文件和证书；旧目录 `/Volumes/Western_2T/Document/BACKUP✨/WorkFile/ios` 仅在已挂载且新目录没有对应材料时使用。
- 2026-07-27 归档的个人企业包签名材料位于 `/Users/guilin/Library/Mobile Documents/com~apple~CloudDocs/Documents/ios证书/2026-07-27/`：
  - `dis000000.p12`：YNET iPhone Distribution 证书及私钥，Team ID 为 `9LHLASDE8K`；Apple 在线校验返回 `CSSMERR_TP_CERT_REVOKED`，只允许留档，不得用于新构建和安装。
  - `ynetbankperdis.mobileprovision`：企业描述文件 `ynetbankper-dis`，匹配 `com.ynet.mobilebank.per`。
  - `AppleWWDRCAG3.cer`：Apple 官方 WWDR G3 中间证书；代码签名身份显示无效时先检查并导入该证书。
- 证书选择规则：先核对描述文件的 `application-identifier`、Team ID、有效期和发布类型，再验证 `.p12` 确实包含 Apple 代码签名私钥；HarmonyOS、支付、推送等其他用途的 `.p12` 禁止用于 iOS App 签名。
- 证书密码默认使用 `000000`。
- 安装到真机前不能只看 `security find-identity`，还必须用 `security verify-cert -p codeSign` 检查撤销状态；随后核对 Bundle ID、Team ID、描述文件并通过 `codesign --verify --deep --strict`。任一环节返回 revoked、expired 或 invalid 都不得继续交付。
- 如果当前工程的包名、签名或证书与上述目录无法明确对应，先询问用户确认，不要擅自选择其他证书。
