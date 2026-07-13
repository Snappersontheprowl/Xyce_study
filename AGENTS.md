# 协作约定（Codex 执行规范）

本文件用于固化本项目的人机协作规则，确保后续会话可以快速恢复一致的工作方式。

## 项目目的
学习 Xyce 仿真器/晶体管级仿真底层原理及工程代码实现。

至于具体的学习计划、约定、方式、节奏等问题，请参考 `/home/eda/my_lab/projects/study/xyce_study/notes/README.md` 。

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

## 基本环境

- 代码编辑工具：`VSCode`
- 项目根目录：`/home/eda/my_lab/projects/study/xyce_study`

## Git 与提交流程

- 项目发生修改后，需及时进行本地 `git commit`。
- 不得擅自回滚或覆盖用户已有未授权变更。

## 重构与代码调整权限

- 涉及代码修改或重构时，可为提升整体清晰性进行必要的：
- 文件/文件夹新增
- 文件/文件夹删除
- 文件/文件夹重命名
- 抵制任何兼容操作。