# Xyce 项目结构总览

记录日期：2026-07-19

## 这份笔记回答什么

这一篇只回答最顶层的问题：

- Xyce 这个项目整体上是怎么分层的
- 哪些目录属于源码主干
- 哪些目录是构建、测试、工具和发布支撑
- 如果只想先建立全局地图，应该先记住什么

## 一句话总览

`Xyce` 的核心代码集中在 `src/`，它不是按零散工具文件堆起来的，而是按仿真子系统拆成多个 package；程序从 `src/Xyce.C` 进入，经 `CircuitPKG` 的顶层 `Simulator` 组织输入、拓扑、器件、装配、分析和求解等主干模块，其余顶层目录主要服务于测试、构建、发布和辅助工具。

## 先看这棵“精简树”

这不是完整目录树，而是一棵足够说明结构的学习版目录树：

```text
Xyce-7.10.0/
├── src/                    # 核心源码
│   ├── Xyce.C             # 程序入口
│   ├── CircuitPKG/        # 顶层仿真器与总调度
│   ├── AnalysisPKG/       # 各类分析调度
│   ├── IOInterfacePKG/    # 命令行、netlist、输出接口
│   ├── TopoManagerPKG/    # 电路拓扑构建
│   ├── DeviceModelPKG/    # 器件框架与模型实现
│   ├── LoaderServicesPKG/ # 从器件到方程装配
│   ├── LinearAlgebraServicesPKG/ # 线性系统与矩阵向量
│   ├── NonlinearSolverPKG/       # 非线性求解
│   ├── TimeIntegrationPKG/       # 时间积分
│   ├── ParallelDistPKG/          # MPI 并行与分布式基础设施
│   └── UtilityPKG/               # 通用基础设施
├── test/                   # 回归测试与包级测试
├── utils/                  # 辅助脚本与外部接口工具
├── cmake/                  # CMake 构建逻辑
├── config/                 # Autotools / 配置探测遗留
├── distribution/           # 打包与发布脚本
├── gitlab-ci/              # CI 配置
└── doc/                    # 上游文档资源
```

## 先把项目分成两层看

### 第一层：源码主干

最重要的只有一个目录：

- `src/`

如果问题是：

- Xyce 怎么启动
- 电路怎样从 netlist 变成内部对象
- 求解器怎样被组织起来
- 分析类型怎样调度

最后几乎都会回到 `src/`。

### 第二层：外围支撑

这些目录很有用，但不是“仿真主执行路径”的第一入口：

- `test/`
- `utils/`
- `cmake/`
- `config/`
- `distribution/`
- `gitlab-ci/`
- `doc/`

它们更多负责：

- 验证
- 构建
- 配置探测
- 打包发布
- 自动化流程
- 辅助接口

## 对学习者最重要的结构判断

如果只是第一轮建立地图，最重要的不是记住所有目录名，而是记住下面 4 个判断：

1. `src/` 是核心中的核心。
2. `src/` 内部的 package 基本对应仿真器的主要子系统，而不是随意的源码分组。
3. `CircuitPKG` 持有顶层 `Simulator`，它是读整体结构时最先要抓住的总控点。
4. Xyce 的结构主线大致是：

```text
入口
  -> 顶层总控
  -> 输入与拓扑
  -> 器件与装配
  -> 分析与求解
  -> 基础设施支撑
```

## 这一层先不要做什么

在总览阶段，先不要急着：

- 深入某个器件模型
- 深入某个 solver 算法
- 深入某个分析类型的生命周期
- 追逐所有目录里的每个文件

总览阶段最重要的是“先建立结构感”，而不是“先掉进细节”。

## 下一步读哪里

读完这篇后，最自然的顺序是：

1. 看 [02-top-level-directories.md](./02-top-level-directories.md)，把顶层目录职责分清
2. 再看 [03-src-package-map.md](./03-src-package-map.md)，把 `src/` 内部 package 地图真正搭起来
3. 最后看 [04-structure-reading-order.md](./04-structure-reading-order.md)，把后续阅读主线固定下来
