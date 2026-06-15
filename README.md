# ClashX for iOS

一个基于 Clash 核心的 iOS VPN 客户端，类似桌面端的 Clash Verge。

## 功能

- [x] VPN 连接管理（一键开关）
- [x] 实时流量监控（上传/下载速度、总量）
- [x] 多种运行模式（规则/全局/直连）
- [x] 配置文件管理（导入/切换/删除）
- [x] 代理节点选择
- [x] 延迟测试
- [x] 实时日志查看
- [x] 深色模式
- [x] 支持所有 Clash 代理协议（Shadowsocks、VMess、Trojan、SOCKS5、HTTP 等）

## 环境要求

### 开发环境
由于 iOS 开发必须在 macOS 上进行，但你**只有 Windows**，我们通过 **GitHub Actions** 自动在云端编译：

| 组件 | 要求 |
|------|------|
| 代码编辑 | 任意操作系统（Windows/Linux/Mac） |
| 编译构建 | GitHub Actions (macOS runner, 免费) |
| 安装部署 | iPhone/iPad + AltStore 或 SideStore |

### iPhone 要求
- iOS 15.0 或更新版本
- [AltStore](https://altstore.io) 或 [SideStore](https://sidestore.io) 用于侧载

## 快速开始

### 1. Fork / Clone 项目

```bash
git clone https://github.com/你的用户名/ClashX-iOS.git
cd ClashX-iOS
```

### 2. 在 GitHub 上启用 Actions

1. 将代码推送到你的 GitHub 仓库
2. 进入仓库 Settings > Secrets and variables > Actions
3. 添加以下密钥：
   - `APPLE_TEAM_ID` — 你的 Apple 开发者 Team ID（免费账号也有，可在 Xcode 或 Apple Developer 网站查看）

### 3. 触发构建

你可以选择以下方式之一触发构建：

#### 方式 A：手动触发（推荐）
1. 打开 GitHub 仓库的 Actions 页面
2. 选择 **Build ClashX IPA** 工作流
3. 点击 **Run workflow** → 选择 `development` → 点击 **Run**

#### 方式 B：推送代码
直接推送到 `main` 或 `master` 分支会自动触发构建。

### 4. 下载 IPA

构建完成后（约 20-30 分钟）：
1. 进入 Actions 页面，找到刚完成的构建
2. 在 **Artifacts** 区域下载 `ClashX-iOS-xxx` 压缩包
3. 解压得到 `ClashX.ipa`

### 5. 安装到 iPhone

使用 AltStore 安装：
1. 在电脑上安装 AltServer
2. 用数据线连接 iPhone
3. 右键 AltServer 图标 → Install AltStore → 选择你的 iPhone
4. 在 iPhone 上打开 AltStore
5. 进入 My Apps → 右上角 + → 选择下载的 ClashX.ipa
6. 输入 Apple ID 和密码（仅用于签名，安全）

或者使用 SideStore（不需要数据线，但需要 WiFi 环境）。

### 6. 使用

1. 在 iPhone 上打开 ClashX
2. 进入"配置管理"页面，导入你的 Clash 配置文件（支持 URL 导入、文件导入、粘贴导入）
3. 返回首页，点击 **连接**
4. 系统会弹出 VPN 配置授权，点击 **允许**
5. 连接成功后，所有流量将通过 Clash 代理

## 项目结构

```
ClashX-iOS/
├── ClashX/                        # 主 App (SwiftUI)
│   ├── ClashXApp.swift             # 应用入口
│   ├── Views/                      # UI 界面
│   │   ├── DashboardView.swift     # 主面板
│   │   ├── ProfilesView.swift      # 配置管理
│   │   ├── ProxyView.swift         # 代理选择
│   │   ├── LogView.swift           # 日志
│   │   └── SettingsView.swift      # 设置
│   ├── ViewModels/                 # 视图模型
│   │   ├── VPNManager.swift        # VPN 状态管理
│   │   ├── ProfileManager.swift    # 配置管理
│   │   └── TrafficMonitor.swift    # 流量监控
│   ├── Models/                     # 数据模型
│   │   ├── ClashConfig.swift
│   │   ├── ProxyNode.swift
│   │   ├── ProxyGroup.swift
│   │   └── Profile.swift
│   └── Services/                   # 服务层
│       ├── ClashController.swift   # Clash HTTP API 通信
│       └── ConfigParser.swift      # 配置解析
├── ClashXTunnel/                   # Network Extension
│   ├── PacketTunnelProvider.swift  # VPN 隧道核心
│   └── TunnelConfig.swift
├── ClashCoreBridge/                # Go 桥接代码 (gomobile)
│   ├── clashcore.go                # Clash 核心接口
│   └── go.mod
├── ClashCore/                      # 编译产物 (构建时生成)
│   └── ClashCore.xcframework
├── Configuration/
│   ├── Info.plist
│   ├── ClashX.entitlements
│   └── ClashXTunnel.entitlements
├── scripts/
│   ├── build_clash_core.sh         # Clash 核心编译脚本
│   └── package.sh                  # IPA 打包脚本
├── .github/workflows/build.yml     # GitHub Actions 配置
└── project.yml                     # XcodeGen 项目定义
```

## 技术架构

```
SwiftUI (UI)
    │
    ▼
VPNManager ──► NETunnelProviderManager
    │
    ▼
ClashController ──► Clash Core (HTTP API)
    │
    ▼
PacketTunnelProvider ──► NEPacketTunnelFlow
    │
    ▼
ClashCore.xcframework (Go via gomobile)
    │
    ▼
Clash Engine (路由规则 + 代理协议)
```

## 常见问题

### 编译失败
- 确保 GitHub Actions 的 macOS runner 正常运行（免费账户每月有 2000 分钟配额）
- 检查 `APPLE_TEAM_ID` 是否正确配置

### 安装后闪退
- 检查证书是否受信任：设置 > 通用 > VPN 与设备管理 > 信任开发者证书
- 如果 7 天后无法打开，重新侧载一次

### VPN 无法连接
- 确保配置文件格式正确（YAML）
- 检查外部控制地址是否为 `127.0.0.1:9090`
- 查看日志页面了解详细错误

## 开发指南

### 如果你有 Mac

在本地开发更快捷：

```bash
# 1. 安装 XcodeGen
brew install xcodegen

# 2. 生成 Xcode 项目
xcodegen generate

# 3. 编译 Clash 核心
./scripts/build_clash_core.sh

# 4. 用 Xcode 打开 ClashX.xcodeproj 并运行
```

### 添加新功能

1. 在 `ClashX/Models/` 中添加数据模型
2. 在 `ClashX/Services/` 中添加服务逻辑
3. 在 `ClashX/ViewModels/` 中添加视图模型
4. 在 `ClashX/Views/` 中添加 UI 界面

## 免责声明

- 本软件仅供学习和研究使用
- 请遵守当地法律法规
- 用户需自行准备合法的代理服务器

## 许可

MIT License
