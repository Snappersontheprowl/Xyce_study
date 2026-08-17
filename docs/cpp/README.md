# C++ 学习补充

## 功能

本目录用于沉淀阅读 Xyce 源码时真正会遇到的 C++ 语法、语义和工程结构知识。

它不是完整 C++ 教材；这里优先记录能帮助读懂 Xyce 的内容。

## 本级模块职责

- `README.md`：说明本目录职责、文件分工和维护约定。
- `syntax-basics.md`：声明、定义、头文件、匿名命名空间等基础语法。
- `xyce-cpp-development-skills.md`：围绕 Xyce 源码阅读和开发的 C/C++ 技能优先级。
- `xyce-reading-structures.md`：阅读 Xyce 时常见的接口、manager、factory、模板和 ownership 结构。
- `career-learning-path.md`：围绕 SPICE / HPC / EDA 自动化方向的 C++ 学习路线。
- `non-eda-cpp-directions.md`：非 EDA 场景下的 C++ 技术方向参考。
- `two-project-research-checklist.md`：对比项目或横向调研时使用的检查清单。

## 命名规则

- 文件名使用英文小写和连字符，例如 `syntax-basics.md`。
- 新主题优先按能力主题命名，不使用 `new`、`final`、`tmp`、`v2` 这类阶段性词。

## 当前约定

- 每篇专题尽量回答“本质问题、最小例子、常见误区、源码阅读提示”。
- 只有当某个 C++ 点在 Xyce 阅读中反复出现时，才沉淀为独立文档。
- 具体源码阅读结论仍放在 `../notes/`，本目录只维护可复用的 C++ 背景知识。
