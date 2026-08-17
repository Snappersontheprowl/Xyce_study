# 笔记目录

## 功能

本目录用于存放按学习阶段和专题整理的 Xyce 源码阅读笔记、构建安装记录和阶段性学习材料。

横向的 C++ 背景知识放在 [../cpp/](../cpp/)；功能验证用例和结果放在 [../../functional-verification/](../../functional-verification/)。

## 本级模块职责

- `README.md`：说明笔记目录的组织方式、命名规则和维护约定。
- `01-overview/`：整体导航地图、高层结构和源码阅读顺序。
- `02-startup/`：程序启动流程与顶层 `Simulator`。
- `03-netlist-and-circuit-build/`：netlist 解析与电路构建。
- `04-device-trace/`：普通器件从网表到实例化、装配的纵向追踪。
- `05-analysis-flow/`：分析调度、对象关系和生命周期控制流。
- `06-solver-and-assembly/`：电路方程、矩阵装配和求解结构。
- `07-device-model-contributions/`：器件模型如何贡献 `Q/F/B/dQdx/dFdx`。
- `08-interfaces/`：Xyce 被 C/Python/REST 等外部接口驱动时的实现层。
- `build-and-install/`：Xyce 及依赖栈的编译、安装、补丁和验证记录。
- `parallel/`：并行相关专题笔记。

## 使用建议

源码阅读主线建议按编号推进：

1. `01-overview/`
2. `02-startup/`
3. `03-netlist-and-circuit-build/`
4. `04-device-trace/`
5. `05-analysis-flow/`
6. `06-solver-and-assembly/`
7. `07-device-model-contributions/`
8. `08-interfaces/`

构建和安装问题直接进入 `build-and-install/`，不必等待源码阅读主线推进。

## 命名规则

- 阶段目录使用两位编号加短名，例如 `05-analysis-flow/`。
- 文件名使用阶段内顺序编号，例如 `01-startup-flow.md`。
- 记录日期写入正文，不放在文件名或 README 标题里。
- 同一专题下的多篇笔记按推荐阅读顺序递增编号。

## 当前约定

- 每份笔记应尽量回答：读了哪些文件、带着什么问题读、当前结论是什么、下一步追踪什么。
- 笔记引用代码文件时应保持阅读顺序，不突然跳入无上下文的新文件。
- README 只维护目录职责和稳定入口；具体分析和阶段结论写入专题文档。
