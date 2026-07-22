# build-and-install

本专题记录 Xyce 的编译、安装、依赖管理和构建验证。它与源码运行时结构阅读分开维护：这里回答“怎样得到一套可复现的 Xyce”，而不是追踪模拟器如何执行。

## 文件索引

- [01-build-and-install-architecture.md](./01-build-and-install-architecture.md)
  建立 Xyce 大型工程的构建全景：工具链、SuiteSparse/Trilinos 依赖栈、CMake 路线、构建目录隔离、功能开关和验收步骤。
- [02-layered-minimal-build-plan.md](./02-layered-minimal-build-plan.md)
  串行 Release 最小配置的可执行计划：前置审计、依赖复用/重建决策、逐层配置命令、验收点与停止条件。

## 专题边界

本目录覆盖：

- 依赖版本与编译器/MPI 一致性
- CMake 配置、编译、安装与清理策略
- 串行、MPI、插件、FFTW 等构建变体
- 冒烟测试、单元测试和回归测试的关系

运行时的启动、netlist 解析、器件装配和求解器实现仍按主学习路线放在其他阶段目录中。
