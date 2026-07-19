# Xyce 并行与“多线程”学习笔记

记录日期：2026-07-19

## 这份笔记要回答什么

这次不是泛泛地聊“Xyce 支持并行”，而是想回答一个更具体的问题：

- 如果我们说“学习 Xyce 中多线程内容”，源码里到底该看哪里
- Xyce 自己实现的到底是 `MPI` 分布式并行，还是大量应用层多线程
- `OpenMP / Kokkos / ShyLU-Basker` 这些关键词在 Xyce 里各自扮演什么角色

## 先说结论

当前这轮阅读得到的最重要结论是：

1. Xyce 的主并行模型首先是 `MPI` 分布式并行，而不是应用层到处铺开的 `std::thread` 或 `#pragma omp`。
2. Xyce 自己维护了一层并行抽象，核心在 `ParallelDistPKG`，它把“串行运行”和“MPI 运行”统一成 `Communicator / Manager / ParMap / GlobalAccessor` 这套接口。
3. 真正和“多线程”最接近的内容，更多出现在依赖库和求解器后端里，尤其是 `Trilinos + OpenMP + Basker / ShyLU-Basker` 这条线。
4. 如果你的目标是“看懂 Xyce 怎样自己管理线程”，那么答案会有点反直觉：源码主干里几乎没有大面积显式线程调度代码；它更像是把线程级并行委托给底层线性求解器和 Trilinos 配置。

换句话说，Xyce 更像：

- 上层自己管 `MPI` 进程间协作与分布式数据结构
- 下层把部分线程级并行交给 Trilinos/Kokkos/OpenMP 支持的 solver backend

## 这次读了哪些文件

- [vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.h](../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.h)
- [vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.C](../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.C)
- [vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_Manager.h](../vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_Manager.h)
- [vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_Manager.C](../vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_Manager.C)
- [vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_Comm.h](../vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_Comm.h)
- [vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_ParallelMachine.h](../vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_ParallelMachine.h)
- [vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_EpetraHelpers.C](../vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_EpetraHelpers.C)
- [vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_EpetraMPIComm.C](../vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_EpetraMPIComm.C)
- [vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_EpetraSerialComm.h](../vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_EpetraSerialComm.h)
- [vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_MPI.h](../vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_MPI.h)
- [vendor/Xyce-7.10.0/src/LinearAlgebraServicesPKG/N_LAS_IRSolver.C](../vendor/Xyce-7.10.0/src/LinearAlgebraServicesPKG/N_LAS_IRSolver.C)
- [vendor/Xyce-7.10.0/cmake/tps.cmake](../vendor/Xyce-7.10.0/cmake/tps.cmake)
- [vendor/Xyce-7.10.0/cmake/trilinos/trilinos-beta.cmake](../vendor/Xyce-7.10.0/cmake/trilinos/trilinos-beta.cmake)
- [vendor/Xyce-7.10.0/cmake/trilinos/trilinos-MPI-beta.cmake](../vendor/Xyce-7.10.0/cmake/trilinos/trilinos-MPI-beta.cmake)
- [vendor/Xyce-7.10.0/README.md](../vendor/Xyce-7.10.0/README.md)
- [vendor/Xyce-7.10.0/INSTALL.md](../vendor/Xyce-7.10.0/INSTALL.md)

## 先把三个概念拆开

“Xyce 的多线程”这个说法很容易把三件不同的事混在一起：

### 1. 串行 build vs MPI build

这是最外层的区分。

- [INSTALL.md](../vendor/Xyce-7.10.0/INSTALL.md) 明确说，Xyce 可以构建成串行执行版本，也可以构建成带分布式内存并行的 `MPI` 版本。
- 这个能力首先取决于 `Trilinos` 是不是按 `MPI` 模式构建。

这意味着：

- “是否并行”首先不是运行时开几个线程的问题
- 而是二进制从一开始就是 `serial` 还是 `MPI-enabled`

### 2. Xyce 主流程里的并行抽象

这是 Xyce 自己实现的那部分。

- `Circuit::Simulator` 在 `RunState` 里把 `PARALLEL_INIT` 作为最早的初始化阶段之一。
- `initializeEarly()` 一上来就创建 `parallelManager_`。
- 之后 analysis、linear system、builder、device 等子系统都会把这个 parallel manager 注册进去。

这说明在 Xyce 设计里，“并行环境”不是线性求解时才临时出现的附属功能，而是整个仿真框架很早就建立的基础设施。

### 3. 真正的线程级并行

这部分目前看主要不在 Xyce 应用层自己展开，而是更多依赖：

- `OpenMP`
- `Kokkos`
- `Basker`
- `ShyLU-Basker`
- 以及 Trilinos 内部的并行能力

所以如果你带着“我要找 Xyce 里哪段 `omp parallel for` 最核心”去读，大概率会失望，因为主干源码里这种痕迹非常少。

## 主流程里，并行是怎样接入的

### `Simulator` 把并行初始化放在非常前面

在 [N_CIR_Xyce.h](../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.h) 里，`RunState` 早早就列出：

- `PARALLEL_INIT`
- `PARSE_COMMAND_LINE`
- `CHECK_NETLIST`
- `ALLOCATE_SUBSYSTEMS`
- `SETUP_TOPOLOGY`
- `SETUP_MATRIX_STRUCTURE`

在 [N_CIR_Xyce.C](../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.C) 的 `initializeEarly()` 里，首先执行的是：

- `runState_ = PARALLEL_INIT`
- `parallelManager_ = new Parallel::Manager(argc, argv, comm_)`

如果当前 `comm_ == MPI_COMM_NULL`，它会从 `parallelManager_->getPDSComm()->comm()` 回填 communicator。

这里的结构意义很强：

- `Simulator` 本身不直接操心 “MPI 或 serial 的细节”
- 它把这件事委托给 `Parallel::Manager`
- 后续所有需要并行上下文的包都复用这一套抽象

### `parallelManager_` 会被多个子系统共享

在 [N_CIR_Xyce.C](../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.C) 里可以看到：

- `Topology` 构造时会接收 `*parallelManager_`
- `analysisManager_->registerParallelServices(parallelManager_)`
- `linearSystem_->registerPDSManager(parallelManager_)`
- `builder_->registerPDSManager(parallelManager_)`
- `deviceManager_->setupExternalDevices(*parallelManager_->getPDSComm())`

这说明 Xyce 的并行不是“某个求解器内部偷偷自己并行”这么简单，而是：

- 顶层先建立统一 communicator 和分布式数据管理器
- 再把它注入 topology、analysis、linear algebra、device 等主干子系统

## `ParallelDistPKG` 是 Xyce 自己的并行抽象层

### `Communicator` 是统一接口

[N_PDS_Comm.h](../vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_Comm.h) 定义了抽象类 `Communicator`，里面统一了：

- `procID() / numProc() / isSerial()`
- `scanSum / sumAll / maxAll / minAll`
- `bcast / send / recv / iRecv / waitAll`
- `pack / unpack`
- `barrier()`
- `comm()`

这个类很关键，因为它说明：

- Xyce 上层逻辑尽量不直接到处写裸 `MPI_*`
- 它想把串行和并行运行统一在一层接口后面

### 串行和 MPI 版本通过工厂切换

在 [N_PDS_EpetraHelpers.C](../vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_EpetraHelpers.C) 的 `createPDSComm(...)` 里：

- 如果定义了 `Xyce_PARALLEL_MPI`
  - 且传入已有 communicator，则构造 `EpetraMPIComm(comm)`
  - 否则构造 `EpetraMPIComm(iargs, cargs)`
- 否则直接构造 `EpetraSerialComm()`

这相当于把“当前这份 Xyce 到底是串行版还是 MPI 版”封装成一个工厂决策。

### 串行实现是一个真正的 no-op communicator

从 [N_PDS_EpetraSerialComm.h](../vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_EpetraSerialComm.h) 可以看出：

- `procID()` 恒为 `0`
- `numProc()` 恒为 `1`
- `isSerial()` 恒为 `true`
- `bcast / send / recv / barrier` 等大量接口本质上直接返回或空操作

这说明很多上层代码可以统一写成“走 communicator 接口”，而不用在每个调用点反复写：

- `if serial ...`
- `if mpi ...`

### `Parallel::Manager` 主要管 map / graph / accessor

[N_PDS_Manager.h](../vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_Manager.h) 和 [N_PDS_Manager.C](../vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_Manager.C) 表明：

- `Manager` 内部拥有一个 `pdsComm_`
- 它维护多个 `ParMap`
- 维护与 map 关联的 `GlobalAccessor`
- 也维护 `Linear::Graph`

这说明 Xyce 自己的“并行层”重点不是线程池，而是：

- 分布式索引映射
- 跨进程访问与规约
- 分布式矩阵/图结构的组织

这和典型共享内存多线程框架的关注点非常不同。

## MPI 初始化和结束点在哪里

### `MPI_Init` 在 `EpetraMPIComm` 创建阶段触发

在 [N_PDS_EpetraMPIComm.C](../vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_EpetraMPIComm.C) 的 `createMPIComm()` 里：

- 先调用 `MPI_Initialized`
- 如果还没初始化，则执行 `MPI_Init`
- 如果外部已经初始化过，则把 communicator 视为非本对象拥有

这个设计意味着：

- Xyce 可以自己启动 MPI
- 也可以嵌入到一个已经启动 MPI 的宿主环境里

这个点对理解外部接口和耦合方式很重要。

### 退出时会走 `MPI_Finalize`

在 [N_CIR_Xyce.C](../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.C) 的 `Xyce_exit()` 里：

- 对称退出时先 `MPI_Barrier`
- 非零错误码会在 rank 0 或 asymmetric 情况下调用 `MPI_Abort`
- 最后 `MPI_Finalize`

所以从生命周期上说：

- `initializeEarly()` 建立并行环境
- `Xyce_exit()` 负责最终结束 MPI 生命周期

## 为什么说“多线程”更多在求解器和 Trilinos 后端

### 源码主干里几乎没有大面积显式线程代码

这次对 `src/` 和 `utils/` 做了关键字搜索：

- 没有找到成体系的 `#pragma omp`
- 没有看到应用层大量使用 `std::thread`
- 也没有看到器件装配主路径里显式线程分工框架

这非常说明问题：

- Xyce 主干应用层主要不是靠自己写线程并行跑起来的
- 至少在 7.10 这个源码快照里，线程级并行不是表层架构主线

### CMake 明确把 OpenMP 和 Trilinos/Kokkos 绑在一起

在 [cmake/tps.cmake](../vendor/Xyce-7.10.0/cmake/tps.cmake) 里有两个很强的信号：

1. 先检查 `Kokkos_DEVICES` 里是否启用了 `OPENMP`
2. 如果启用了，就 `find_package(OpenMP REQUIRED)`

这说明：

- OpenMP 在这里首先是为了匹配 Trilinos/Kokkos 的配置
- 它不是简单地“Xyce 自己源码里到处要用 omp”

### `trilinos-beta.cmake` 和 `trilinos-MPI-beta.cmake` 把 ShyLU-Basker 说得很直接

这两个文件里都有非常直白的注释：

- `ShyLU-Basker requires OpenMP`
- `OMP_NUM_THREADS` 需要设置到合理值

这几乎已经把“线程级并行主要落在哪”点明了：

- 线程能力更多来自 `ShyLU-Basker` 这样的求解器后端
- 不是 Xyce 顶层业务代码自己实现一个线程调度框架

### `IRSolver` 里能看到对线程型 solver backend 的选择

在 [N_LAS_IRSolver.C](../vendor/Xyce-7.10.0/src/LinearAlgebraServicesPKG/N_LAS_IRSolver.C) 中：

- `type_ == "SHYLU_BASKER"` 时会选择 `solverType = "ShyLUBasker"`
- `type_ == "BASKER"` 时会选择 `solverType = "Basker"`

再结合 `tps.cmake` 中：

- `Xyce_AMESOS2_SHYLUBASKER` 的注释直接写着 “multi-threaded ShyLU-Basker linear solver”

就可以把逻辑串起来：

- Xyce 上层暴露 solver 选择
- 线程级并行主要体现在线性求解器 backend 是否启用带 OpenMP 的实现

## 所以，“Xyce 的多线程”更准确的表述是什么

更准确地说，应该分成三句话：

1. Xyce 本体是一个从架构上面向并行的模拟器，但它的主并行模型首先是 `MPI` 分布式并行。
2. Xyce 自己实现的并行基础设施主要是 communicator、分布式 map、跨进程规约和图/矩阵分布管理。
3. 真正的共享内存多线程能力，当前主要依赖 Trilinos/Kokkos/OpenMP 以及诸如 `Basker / ShyLU-Basker` 这样的求解器后端，而不是 Xyce 应用层自己广泛手写线程。

这能解释一个常见困惑：

- 为什么 README 会强调 “parallel simulation code”
- 但你在主干源码里却很难找到很多显眼的 OpenMP 业务循环

因为这里的“parallel”首先说的是：

- MPI + distributed data structures + scalable solver stack

而不是“应用层每个器件装配循环都直接开多线程”。

## 这轮阅读后，我会怎样继续往下钻

如果下一轮要继续深入，我建议按这个顺序：

1. 先读 [vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_EpetraMPIComm.h](../vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_EpetraMPIComm.h) 和对应 `.C`
   目标：把 communicator wrapper 的完整能力摸清，尤其是 `sumAll / maxAll / pack / async recv` 的实际封装方式。
2. 再追 `Topology` 和 `Linear::System` 如何消费 `parallelManager_`
   目标：看分布式拓扑划分、矩阵 map、overlap map 是在哪些阶段真正建立起来的。
3. 最后单独开一条“线程型 solver backend”支线
   目标：把 `Basker / ShyLU-Basker / Amesos2 / Kokkos / OpenMP` 的关系单独做成一张图。

## 这轮最值得记住的判断

如果只是想先抓住主线，请记住这一句：

> 在 Xyce 里，先学“MPI 并行框架”比先找“业务层多线程代码”更重要；多线程更多是 solver backend 能力，而不是应用层主叙事。

## 下一轮可直接回答的自测题

1. `parallelManager_` 是在 Xyce 生命周期的哪个阶段创建的，为什么它必须足够早？
2. `Communicator` 抽象帮 Xyce 隐藏了哪些“串行 vs MPI”差异？
3. 为什么 `ShyLU-Basker requires OpenMP` 这句话比单纯搜索 `#pragma omp` 更能说明 Xyce 的多线程落点？
4. 如果你要研究“Xyce 自己的并行机制”，为什么应该优先读 `ParallelDistPKG` 而不是先读某个器件模型？
