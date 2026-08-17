# 01-overview

## 功能

本目录用于建立 Xyce 源码学习的整体地图：项目顶层结构、核心源码包分工和后续阅读顺序。

本目录不展开具体分析算法、器件模型装配或求解器数学细节。

## 本级模块职责

- `README.md`：说明本目录职责和阅读顺序。
- `01-project-structure-map.md`：Xyce 项目的一句话总览、精简目录树和分层地图。
- `02-top-level-directories.md`：顶层目录职责、学习优先级和边界。
- `03-src-package-map.md`：`src/` 核心 package 的职责分层。
- `04-structure-reading-order.md`：从入口到主干子系统的阅读顺序。

## 使用建议

建议按文件编号顺序阅读。读完本目录后，再进入 `02-startup/` 追踪程序入口和顶层 `Simulator`。

## 当前约定

- 本目录只回答“项目如何分层”和“先读哪里”。
- 具体执行链、器件模型、solver、并行和接口专题放在后续目录中。
