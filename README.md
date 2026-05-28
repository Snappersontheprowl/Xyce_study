# Xyce 源码学习仓库

这个仓库是一个用于阅读和整理 Xyce 源码的个人学习工作区。

目标不是维护一个 Xyce 分叉版本，而是把源码快照、学习笔记、阅读计划和辅助脚本放在一个结构清晰的地方，方便长期积累。

## 仓库结构

- `vendor/Xyce-7.10.0/`：本地解压后的 Xyce 源码快照，用于阅读
- `artifacts/source/`：下载的发布包归档，不纳入版本控制
- `docs/`：结构化的学习文档和主题总结
  其中 `docs/cpp/` 专门用于沉淀 C++ 语言学习笔记和自测题
- `notes/`：按日期记录的阅读笔记、追踪过程和简短结论
- `scripts/`：用于检索、构建或追踪源码的辅助脚本

## 版本控制策略

- 这个仓库只跟踪学习资料，不跟踪 Xyce 上游源码树本身。
- `vendor/Xyce-7.10.0/` 保留在本地，但被 Git 忽略。
- `artifacts/source/Release-7.10.0.tar.gz` 也保留在本地，但被 Git 忽略。

这样既能保持学习仓库足够轻量，也能保留当前阅读所对应的稳定源码副本。

## 官方来源

截至 2026-05-12：

- 官方项目主页：https://xyce.sandia.gov/
- 官方源码下载页：https://xyce.sandia.gov/downloads/source-code/
- 官方 GitHub 仓库：https://github.com/Xyce/Xyce

## 版本说明

- GitHub 默认分支是 `master`。
- 当前发布标签是 `Release-7.10.0`。
- Sandia 下载页列出的当前源码版本是 `Xyce-7.10.tar.gz`。
- 本地源码目录是解压得到的发布版快照，不是 Git checkout。

如果以后需要查看完整的上游提交历史，可以单独克隆官方仓库：

```bash
git clone https://github.com/Xyce/Xyce.git
```

## 第一轮阅读目标

第一轮源码阅读建议先完成这几件事：

1. 找到程序入口和顶层驱动流程。
2. 确认 netlist 在哪里被解析。
3. 追踪一个简单器件，例如电阻。
4. 梳理矩阵装配和求解器调用发生的位置。
