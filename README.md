# OpenMathInk Collector

> SwiftUI + PencilKit 手写数据集采集工具。

用于采集数学手写数据并将其标注为 LaTeX 公式，为 OpenMathInk Dataset 提供数据源。

## 在生态系统中的位置

- **eMathica Core** — 主应用，数学创作平台
- **OpenMathInk Collector** ← 你在这里
- **OpenMathInk Dataset** — 数据集（采集数据的接收方）
- **SharedLibraries** — 共享 Swift Packages

Current shared dependency root: `SharedLibraries/`
Target shared package layout: `Packages/shared/`

OpenMathInkCollector should not depend on eMathica-only creative capabilities such as Canvas, CAS, Graphing, or Sampling.

## 功能

- PencilKit 手写捕获
- LaTeX 公式标注输入
- 本地样本管理（创建、编辑、确认）
- 本地文件持久化（JSON + PNG + .drawing）
- 数据集打包导出
- 贡献者同意书管理

## 快速开始

1. 在 Xcode 中创建 iPadOS/macOS SwiftUI App 项目
2. 添加 `OpenMathInkCollector/` 目录下所有文件到 App Target
3. 确保启用 PencilKit 能力
4. 在 iPad 模拟器/设备上运行

## 当前导出格式

`OpenMathInkDataset_YYYYMMDD_HHMMSS/`
- `manifest.json` — 数据集清单
- `consent.json` — 贡献者同意书
- `license.txt` — 许可证
- `privacy_notice.txt` — 隐私声明
- `samples/*.json` — 样本元数据
- `samples/*.png` — 手写渲染图
- `samples/*.drawing` — PencilKit 笔触数据

> ZIP 压缩导出已预留为后续扩展点；当前 MVP 直接导出文件夹供 ShareLink 使用。
