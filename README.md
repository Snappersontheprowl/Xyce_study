# Xyce 源码学习仓库

本仓库是用于学习 Xyce 仿真器源码、构建流程和基础验证方法的个人工作区。

项目关注三件事：

1. 阅读 Xyce 源码，理解 SPICE 类仿真器的网表解析、器件建模、矩阵装配、非线性求解和分析流程；
2. 记录 Xyce 及其依赖的本地编译、安装、补丁和环境配置；
3. 通过小型可复现用例验证当前安装的功能边界，为后续源码学习提供参照。

本仓库不是 Xyce 上游分叉，也不以维护可发布版本为目标。上游源码、构建产物和下载归档主要保留在本地，项目 Git 重点跟踪学习笔记、验证用例、构建记录和少量必要补丁。

## 仓库结构

本级目录如下：

```text
.
├── AGENTS.md
├── README.md
├── artifacts/
├── build/
├── docs/
├── functional-verification/
├── notes/
├── out/
├── scripts/
└── vendor/
```

各项职责：

- `AGENTS.md`：本项目的人机协作约定和执行规范。
- `README.md`：项目入口说明。
- `artifacts/`：本地下载或保留的源码包、工具包等归档文件。
- `build/`：本地构建目录、编译中间产物和构建日志。
- `docs/`：横向专题文档，例如 C++ 阅读补充。
- `functional-verification/`：当前 Xyce 安装的功能验证计划、用例和结果记录。
- `notes/`：源码阅读笔记、构建安装笔记和阶段性学习记录。
- `out/`：本地安装前缀，例如已安装的 Xyce、依赖库和工具。
- `scripts/`：项目辅助脚本。
- `vendor/`：本地展开的第三方/上游源码快照，例如 Xyce 源码。

## 主要入口

学习计划与笔记索引：

```text
notes/README.md
```

构建与安装记录：

```text
notes/build-and-install/
```

功能验证工作区：

```text
functional-verification/
```

当前本地 Xyce 源码快照：

```text
vendor/Xyce-7.10.0/
```

## 当前工作对象

当前主要学习和验证对象是 Xyce 7.10.0：

```text
vendor/Xyce-7.10.0/
```

当前项目内安装的 Xyce 可执行文件位于：

```text
out/xyce-7.10-serial-release/bin/Xyce
```

确认版本：

```bash
cd /home/eda/my_lab/projects/study/xyce_study
out/xyce-7.10-serial-release/bin/Xyce -v
```

## 版本控制策略

本仓库主要跟踪：

- 学习笔记；
- 构建与安装记录；
- 功能验证用例；
- 小型文本结果；
- 为完成本地构建所需的补丁说明。

本仓库通常不跟踪：

- 上游源码树本体；
- 大型源码包和二进制工具包；
- 构建中间产物；
- 本地安装输出；
- 临时日志。

对应地，以下目录主要作为本地工作区使用：

```text
vendor/
artifacts/
build/
out/
```

如需复现某个阶段，应优先查看 `notes/` 和 `functional-verification/` 中的记录，而不是依赖未纳入 Git 的构建产物。

## 官方来源

- Xyce 官方主页：https://xyce.sandia.gov/
- Xyce 官方源码下载页：https://xyce.sandia.gov/downloads/source-code/
- Xyce 官方 GitHub 仓库：https://github.com/Xyce/Xyce
- XDM GitHub 仓库：https://github.com/Xyce/XDM

如果需要查看完整上游提交历史，可以单独克隆官方仓库：

```bash
git clone https://github.com/Xyce/Xyce.git
```
