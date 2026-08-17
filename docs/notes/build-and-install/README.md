# build-and-install

## 功能

本目录记录 Xyce 的编译、安装、依赖管理、补丁和构建验证。

本目录回答“怎样得到一套可复现的 Xyce”；运行时结构阅读放在其它源码学习专题中。

## 本级模块职责

- `README.md`：说明构建安装专题职责、文件分工和边界。
- `01-build-and-install-architecture.md`：大型工程构建全景，包括工具链、依赖栈、CMake 路线和验收步骤。
- `02-layered-minimal-build-plan.md`：串行 Release 最小配置的分层构建计划。
- `03-gcc-toolchain-check.md`：GCC/Clang、`gcc-toolset-15` 可用性和编译器策略记录。
- `04-layered-minimal-build-execution-log.md`：最小分层构建的执行证据、失败诊断和阶段判断。
- `patches/`：为完成本地构建所需的补丁文件。

## 使用建议

复现构建时先读 `01-build-and-install-architecture.md` 建立全景，再按 `02-layered-minimal-build-plan.md` 执行；实际历史证据查 `04-layered-minimal-build-execution-log.md`。

## 当前约定

- 构建日志和诊断结论可以进入专题文档，但 README 只维护长期稳定入口。
- 运行时启动、netlist 解析、器件装配和求解器实现不在本目录展开。
