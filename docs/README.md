# 文档目录

## 功能

本目录是项目文档总入口，用于存放长期维护的学习资料、阅读计划、横向专题和 README 写作规范。

本目录不保存构建产物、仿真输出或临时下载文件；这些内容分别放在 `build/`、`out/`、`artifacts/` 或 `functional-verification/`。

## 本级模块职责

- `README.md`：说明 `docs/` 本级目录的职责和稳定入口。
- `README_GUIDE.md`：仓库内 README 分层写作规范。
- `learning-outline.md`：阶段性学习大纲。
- `reading-plan.md`：当前阅读计划。
- `cpp/`：阅读 Xyce 时需要补齐的 C++ 语言和工程结构知识。
- `notes/`：按学习阶段组织的源码阅读笔记、构建安装记录和专题笔记。
- `tmp_notes/`：尚未整理进主线的临时草稿或素材。

## 使用建议

新读者建议先看：

1. [notes/README.md](./notes/README.md)
2. [learning-outline.md](./learning-outline.md)
3. [reading-plan.md](./reading-plan.md)

如果遇到 C++ 语法或工程结构障碍，再回到 [cpp/README.md](./cpp/README.md) 做横向补课。

## 当前约定

- README 只维护当前目录的一层职责和稳定入口，具体正文放在专题文档中。
- 已整理进主线的草稿应从 `tmp_notes/` 迁出或归档，避免长期形成第二套事实来源。
- 新增文档时优先选择已有专题目录；只有确实属于横向长期内容时，才放在 `docs/` 本级。
