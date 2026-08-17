# Xyce `src/` 包结构地图

记录日期：2026-07-19

## 这篇的目标

这一篇要回答的是：

- `src/` 里有哪些主要 package
- 它们应该怎样分层理解
- 哪些 package 是第一轮阅读最关键的骨架

## 先把 `src/` 看成四层

从结构学习角度，`src/` 最适合先分成四层来看：

1. 入口与总控
2. 输入、电路构建、器件接入
3. 分析与求解
4. 横向基础设施

这比按字母顺序或目录顺序看更接近“程序如何工作”。

## 第一层：入口与总控

### `Xyce.C`

这是可执行程序入口所在文件。

结构上它负责：

- 进入 `main()`
- 构造顶层 simulator
- 把控制权交给仿真主流程

它不是算法主体，但它是整条阅读主线的起点。

### `CircuitPKG`

这是整个 `src/` 里最值得先抓住的 package。

当前最重要的结构认识是：

- 顶层 `Simulator` 在这里
- 初始化阶段的组织在这里
- 多个核心子系统在这里被挂接和调度

如果把 Xyce 看成一个系统，`CircuitPKG` 更像：

- 总装配点
- 总调度点
- 结构主线的第一落脚点

## 第二层：输入、电路构建、器件接入

这一层解决的问题是：

- 外部 netlist 怎样进入系统
- 电路内部拓扑怎样建立
- 器件怎样实例化
- 器件贡献怎样被装配到方程系统里

### `IOInterfacePKG`

这一层主要和外部输入输出接口有关，例如：

- 命令行
- netlist
- 输出管理

它是“外部描述进入内部系统”的入口层之一。

### `TopoManagerPKG`

这个 package 主要承接电路拓扑相关职责。

结构上可以先把它理解成：

- 节点
- 连接关系
- 拓扑组织

它是从文本电路走向内部图结构的关键一环。

### `DeviceModelPKG`

这是 `src/` 里最庞大、也最重要的包之一。

结构上它至少包含两类内容：

1. 通用器件框架
2. 具体器件模型实现

可以先这样看它的内部：

- `Core/`：器件抽象、实例、模型、管理器、注册框架
- `OpenModels/`：常见基础器件模型
- `ADMS/`：由 ADMS 相关流程引入的模型
- 其他专门模型目录：例如神经、TCAD、Sandia 内部模型等

所以它不是“一个器件目录”，而是“整个器件生态系统”。

### `LoaderServicesPKG`

这个包在结构上很关键，因为它处在“器件”和“求解系统”之间。

可以先把它理解成：

- 负责把器件与拓扑信息转成求解器需要的装配接口

它是“从器件世界走向方程系统”的桥梁层。

## 第三层：分析与求解

这一层解决的问题是：

- 当前到底要做哪种分析
- 方程系统如何建立
- 线性和非线性问题如何求解
- 瞬态积分和更高级分析如何接进去

### `AnalysisPKG`

这一层主要负责分析类型管理与调度。

可以先把它理解成：

- `.OP / .DC / .TRAN / .AC / NOISE / HB ...` 的统一组织层

它回答的不是“某个矩阵怎样解”，而是“当前这轮仿真应走哪种分析流程”。

### `LinearAlgebraServicesPKG`

这是线性代数基础设施层。

结构上可先记住它负责：

- 矩阵
- 向量
- 线性系统
- 线性求解服务

它是求解基础设施中的核心一层。

### `NonlinearSolverPKG`

这部分主要承接非线性求解。

结构上可先理解为：

- 牛顿法相关实现
- 非线性求解框架
- 与外部非线性求解库的衔接

### `TimeIntegrationPKG`

这一层与瞬态分析的时间积分强相关。

可以先把它看成：

- `TRAN` 分析的重要基础设施
- 时间推进与误差控制所在层

### `MultiTimePDEPKG`

这个包不是第一轮阅读的核心，但从结构上很有辨识度。

它说明：

- Xyce 不只处理最基础的分析
- 还包含更复杂的多时间尺度或扩展分析能力

### `DakotaLinkPKG`

这个包体现的是与外部优化/不确定性框架的连接能力。

它在整体结构里不是总控主线，但能说明 Xyce 的工程外延。

## 第四层：横向基础设施

这一层不一定直接定义某种分析流程，但很多主线都会依赖它们。

### `ParallelDistPKG`

这是并行与分布式基础设施层。

当前先把它理解成：

- MPI 通信抽象
- 分布式 map / graph / communicator
- 并行运行所需的底层服务

它是横向支撑层，不是顶层算法调度层。

### `UtilityPKG`

这是通用基础设施仓库。

它通常包含：

- 日志
- 参数
- 表达式
- 定时器
- 工具类
- 各种跨模块复用的公共组件

可以把它理解成：

- “整个项目共用的工具箱”

### `ErrorHandlingPKG`

这一层主要负责：

- 错误管理
- 消息与报告机制

它不直接决定分析流程，但决定了系统如何汇报问题和组织错误处理。

### `headers/`

这个目录更像公共头文件收纳位置，不是第一阶段建立结构地图时的主角。

### `cmake/` 与 `test/` 子目录

`src/` 内部也有局部构建和测试支撑目录，但它们不是理解 `src/` 主功能分层的重点。

## 第一轮最该抓住的 8 个 package

如果只想先把骨架立起来，优先记住这 8 个：

1. `CircuitPKG`
2. `AnalysisPKG`
3. `IOInterfacePKG`
4. `TopoManagerPKG`
5. `DeviceModelPKG`
6. `LoaderServicesPKG`
7. `LinearAlgebraServicesPKG`
8. `NonlinearSolverPKG`

原因很简单：

- 它们能基本拼出从输入到求解的主干结构

## 这一篇的核心结论

`src/` 不是“一个大源码目录”，而是一张很清晰的系统分工图：

- `CircuitPKG` 管总控
- `IOInterfacePKG + TopoManagerPKG + DeviceModelPKG + LoaderServicesPKG` 管电路进入系统
- `AnalysisPKG + LinearAlgebraServicesPKG + NonlinearSolverPKG + TimeIntegrationPKG` 管仿真真正算起来
- `ParallelDistPKG + UtilityPKG + ErrorHandlingPKG` 提供横向基础设施

## 下一步

读完这里后，下一步就该看 [04-structure-reading-order.md](./04-structure-reading-order.md)，把这些 package 放进一条真正可执行的阅读主线里。
