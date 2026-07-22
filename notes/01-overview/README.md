# 01-overview

本级目录只负责将 Xyce 的整体结构讲清楚，不展开具体算法细节，不追某条执行链的实现细节。

这一级的目标只有 4 个：

- 先知道 Xyce 作为一个项目，顶层目录怎么分层
- 再知道 `src/` 作为核心源码区，主要 package 如何分工
- 再把“程序从哪里进来、结构上怎么流动”讲清楚
- 给出后续阅读主线，让读者知道下一步该读哪里

## 文件索引

- [01-project-structure-map.md](./01-project-structure-map.md)
  先给整个项目的一句话总览、精简目录树和总分层。
- [02-top-level-directories.md](./02-top-level-directories.md)
  单独解释仓库顶层目录，各目录在学习中的优先级和职责边界。
- [03-src-package-map.md](./03-src-package-map.md)
  把 `src/` 里的核心 package 按职责分层整理，建立真正的源码地图。
- [04-structure-reading-order.md](./04-structure-reading-order.md)
  说明从入口到各主干子系统的结构主线，以及最适合的阅读顺序。
- [05-build-and-install-architecture.md](./05-build-and-install-architecture.md)
  从依赖栈、CMake、构建目录隔离到测试验收，解释 Xyce 大型工程的编译与安装模型。

## 本目录的边界

下面这些内容不在本级目录里展开：

- 某个具体分析类型怎么实现
- 某个器件模型怎么装配
- 某个 solver 的数学与代码细节
- 多线程、MPI、灵敏度、HB 等专题深挖

这些属于后续专题目录或 `docs/` 下的横向文档。
