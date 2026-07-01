# Status — OpenMathInk Collector

> 当前项目状态。

## 当前目标

完成 MVP：本地手写采集 → LaTeX 标注 → 数据集导出闭环。

## 已完成

- 本地样本创建/编辑/确认流程
- PencilKit 手写捕获集成
- LaTeX 公式键盘输入
- 预览渲染器占位（LatexRenderService 协议预留）
- 本地文件持久化（JSON + PNG + .drawing）
- 样本数据集打包导出（文件夹格式）
- 贡献者同意书与隐私声明流程
- 撤销/重做系统

## 正在开发

| 模块 | 优先级 | 说明 |
|------|--------|------|
| Handwriting Collection | Active | PencilKit 画布，Apple Pencil 输入，笔触管理 |
| Formula Labeling | Active | LaTeX 输入、样本标注、状态管理 |
| Data Export | Active | DatasetPackageBuilder 数据包构建 |
| Consent Flow | Active | 贡献者同意书、隐私声明 |
| Undo/Redo | Active | 基于 UndoRedoManager |

## 未开始

- ZIP 压缩导出
- OpenMathInk Dataset 直接集成
- 样本审核/质量评估
- 批量导入
