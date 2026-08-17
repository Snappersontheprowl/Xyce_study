# Xyce 源码学习仓库

## 功能

本仓库是一个用于学习 Xyce 仿真器源码、构建流程和基础验证方法的个人工作区。

它主要服务三件事：

- 阅读 Xyce 源码，理解 SPICE 类仿真器的网表解析、器件建模、矩阵装配、非线性求解和分析流程；
- 记录 Xyce 及其依赖的本地编译、安装、补丁和环境配置；
- 通过小型可复现用例验证当前安装的功能边界，为后续源码学习提供参照。

本仓库不是 Xyce 上游分叉，也不以维护可发布版本为目标。上游源码、构建产物和下载归档主要保留在本地；项目 Git 重点跟踪学习笔记、验证用例、构建记录和少量必要补丁。

## 本级模块职责

本级目录如下：

```text
.
├── AGENTS.md
├── README.md
├── artifacts/
├── build/
├── docs/
├── functional-verification/
├── out/
├── scripts/
└── vendor/
```

各项职责：

- `AGENTS.md`：本项目的人机协作约定和执行规范。
- `README.md`：项目入口说明，只维护本级目录职责和稳定入口。
- `artifacts/`：本地源码包、工具包等归档文件。
- `build/`：本地构建目录、编译中间产物和构建日志。
- `docs/`：文档总目录，包含源码阅读笔记、构建安装记录和横向专题文档。
- `functional-verification/`：当前 Xyce 安装的功能验证计划、用例和结果记录。
- `out/`：本地安装前缀，例如已安装的 Xyce、依赖库和工具。
- `scripts/`：项目辅助脚本。
- `vendor/`：本地展开的第三方或上游源码快照，例如 Xyce 源码。

## 常用入口

- [docs/README.md](./docs/README.md)：文档目录入口。
- [docs/notes/README.md](./docs/notes/README.md)：源码阅读、构建安装和阶段性学习笔记索引。
- [docs/notes/build-and-install/](./docs/notes/build-and-install/)：Xyce 与依赖栈的构建安装记录。
- [functional-verification/README.md](./functional-verification/README.md)：功能验证工作区入口。
- [functional-verification/02-verification-results.md](./functional-verification/02-verification-results.md)：已执行验证用例的结果汇总。
- [vendor/Xyce-7.10.0/](./vendor/Xyce-7.10.0/)：当前本地 Xyce 源码快照。

## 当前约定

- 根 README 只说明项目功能、本级目录职责和稳定入口；具体学习内容进入 `docs/`，具体验证结论进入 `functional-verification/`。
- 构建、安装、下载和编译中间产物优先放在 `artifacts/`、`build/`、`out/`、`vendor/` 等本地工作目录。
- 项目 Git 主要跟踪 Markdown 笔记、验证用例、小型文本结果和必要补丁说明。
- 如需复现某个阶段，优先查看 `docs/notes/` 和 `functional-verification/` 中的记录，不依赖未纳入 Git 的本地构建产物。

## 官方来源

- Xyce 官方主页：https://xyce.sandia.gov/
- Xyce 官方源码下载页：https://xyce.sandia.gov/downloads/source-code/
- Xyce 官方 GitHub 仓库：https://github.com/Xyce/Xyce
- XDM GitHub 仓库：https://github.com/Xyce/XDM
