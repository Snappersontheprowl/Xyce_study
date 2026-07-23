# Xyce 源码学习仓库

## 项目目的
这个仓库是一个用于阅读和整理 Xyce 源码的个人学习工作区。主要有以下目的：
1. Xyce 源码学习，包括 Xyce 仿真器/晶体管级仿真底层原理及工程代码实现。
2. Xyce 这个大型CPP 项目的构建，包括源码及依赖的编译安装
3. 也可能尝试更改源码实现某些想要的功能，暂定。

至于具体的学习计划、约定、方式、节奏等问题，请参考 `/home/eda/my_lab/projects/study/xyce_study/notes/README.md` 。

目标不是维护一个 Xyce 分叉版本，而是把源码快照、学习笔记、阅读计划和辅助脚本放在一个结构清晰的地方，方便长期积累。

## 仓库结构

- `vendor/Xyce-7.10.0/`：本地解压后的 Xyce 源码快照，用于阅读
- `artifacts/source/`：下载的发布包归档，不纳入版本控制
- `docs/`：结构化的学习文档和主题总结
  其中 `docs/cpp/` 专门用于沉淀 C++ 语言学习笔记和自测题
- `notes/`：按日期记录的阅读笔记、追踪过程和简短结论
- `scripts/`：用于检索、构建或追踪源码的辅助脚本

## 本级目录下：
.
├── AGENTS.md
├── artifacts       // 历史遗留文件，主要是 Xyce 源码压缩包
├── build           // 编译过程中的生成物
├── docs            // 存放项目所有文档
├── notes           // 存放源码学习笔记
├── README.md
├── scripts         // 存放有用的脚本
└── vendor          // 存放实际源码

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

