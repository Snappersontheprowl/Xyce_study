# Xyce 并行学习笔记

记录日期：2026-07-20

## 这份笔记要回答什么

这份笔记不再把“并行”拆成一堆零散点，而是按自顶向下的顺序回答：

- Xyce 的并行能力在整个项目结构里处于什么位置
- 顶层 `Simulator` 是怎样把并行能力接进主流程的
- Xyce 自己实现了哪些并行抽象
- 分布式数据结构和通信能力落在哪一层
- 真正接近“多线程”的内容为什么主要落在 solver backend

换句话说，这份笔记要把 Xyce 的并行相关内容从顶层一直讲到底层。

## 这次读了哪些文件

- [vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.h](../../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.h)
- [vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.C](../../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.C)
- [vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_Manager.h](../../vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_Manager.h)
- [vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_Manager.C](../../vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_Manager.C)
- [vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_Comm.h](../../vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_Comm.h)
- [vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_ParallelMachine.h](../../vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_ParallelMachine.h)
- [vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_EpetraHelpers.C](../../vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_EpetraHelpers.C)
- [vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_EpetraMPIComm.C](../../vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_EpetraMPIComm.C)
- [vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_EpetraSerialComm.h](../../vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_EpetraSerialComm.h)
- [vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_MPI.h](../../vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_MPI.h)
- [vendor/Xyce-7.10.0/src/LinearAlgebraServicesPKG/N_LAS_IRSolver.C](../../vendor/Xyce-7.10.0/src/LinearAlgebraServicesPKG/N_LAS_IRSolver.C)
- [vendor/Xyce-7.10.0/cmake/tps.cmake](../../vendor/Xyce-7.10.0/cmake/tps.cmake)
- [vendor/Xyce-7.10.0/cmake/trilinos/trilinos-beta.cmake](../../vendor/Xyce-7.10.0/cmake/trilinos/trilinos-beta.cmake)
- [vendor/Xyce-7.10.0/cmake/trilinos/trilinos-MPI-beta.cmake](../../vendor/Xyce-7.10.0/cmake/trilinos/trilinos-MPI-beta.cmake)
- [vendor/Xyce-7.10.0/README.md](../../vendor/Xyce-7.10.0/README.md)
- [vendor/Xyce-7.10.0/INSTALL.md](../../vendor/Xyce-7.10.0/INSTALL.md)

## 先给总判断

如果只记一句话，这句最重要：

> Xyce 的主并行模型首先是 `MPI` 分布式并行；Xyce 自己负责顶层接线、通信抽象和分布式数据结构，线程级并行更多下沉在 Trilinos / Basker / ShyLU-Basker 这类 solver backend。

这句话把整个层次先压缩成三层：

1. 顶层：`Simulator` 把并行环境接进主流程。
2. 中层：`ParallelDistPKG` 提供 communicator、manager、map、graph、reduce 等并行基础设施。
3. 底层：Trilinos/Kokkos/OpenMP/Basker 等 solver backend 提供线程级并行能力。

下面按这个顺序展开。

## 第 0 层：项目级并行语义

这一层还没进 `src/`，但它决定了后面所有代码该怎样理解。

### Xyce 的“parallel”首先指什么

从 [README.md](../../vendor/Xyce-7.10.0/README.md) 和 [INSTALL.md](../../vendor/Xyce-7.10.0/INSTALL.md) 可以提炼出两个稳定事实：

- Xyce 被设计成一个 parallel simulation code。
- 这个 parallel 首先是 distributed-memory 的 `MPI` 并行。

也就是说，Xyce 的“并行”首先不是：

- 应用层到处写 `std::thread`
- 每个器件装配循环里大量 `#pragma omp`

而是：

- 多进程
- 分布式数据结构
- 可扩展求解栈

### 串行 build 和 MPI build 是最外层开关

[INSTALL.md](../../vendor/Xyce-7.10.0/INSTALL.md) 很明确：

- Xyce 可以构建成串行版本
- 也可以构建成带 `MPI` 的分布式并行版本

这意味着：

- “并行模式”不是运行时临时开几个线程这么简单
- 它从 build 期就已经决定了系统底层如何组织

## 第 1 层：顶层 `Simulator` 如何接入并行

这一层是最重要的顶层入口层。

### 并行初始化在顶层生命周期里非常靠前

在 [N_CIR_Xyce.h](../../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.h) 的 `RunState` 里，`PARALLEL_INIT` 就被放在很前面。

这说明作者的设计意图非常清楚：

- 并行环境不是某个局部模块的可选附属物
- 它是整个仿真框架的基础设施之一

### `initializeEarly()` 创建 `parallelManager_`

在 [N_CIR_Xyce.C](../../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.C) 的 `initializeEarly()` 中，一开始就有：

- `runState_ = PARALLEL_INIT`
- `parallelManager_ = new Parallel::Manager(argc, argv, comm_)`

如果当前 `comm_` 还是空 communicator，它还会从 `parallelManager_->getPDSComm()->comm()` 回填。

结构意义是：

- 顶层 `Simulator` 不直接写大量 MPI 细节
- 它通过 `Parallel::Manager` 拿到统一的并行服务入口

### 并行能力会被注入多个主干子系统

顶层代码里还能看到这些接线点：

- `analysisManager_->registerParallelServices(parallelManager_)`
- `linearSystem_->registerPDSManager(parallelManager_)`
- `builder_->registerPDSManager(parallelManager_)`
- `deviceManager_->setupExternalDevices(*parallelManager_->getPDSComm())`
- `Topology` 构造也会接收 `*parallelManager_`

这一层最关键的认识是：

- Xyce 并行不是一个孤立 package 自己玩自己的
- 它是一个横向基础设施，从顶层被统一接进 analysis、linear algebra、topology、device 等主流程

## 第 2 层：`ParallelDistPKG` 是并行抽象层

如果说第 1 层是在回答“并行从哪里接进来”，那第 2 层就在回答：

- Xyce 自己到底实现了什么并行基础设施

答案基本集中在 `ParallelDistPKG`。

### 这一层的核心角色

当前最值得抓住的 4 个角色是：

1. `Communicator`
2. `Manager`
3. `ParMap`
4. `GlobalAccessor`

再加上和矩阵结构相关的 `Graph`，就形成了 Xyce 自己并行层的骨架。

### 这一层不是什么

为了避免误解，也要明确它不是什么：

- 不是线程池实现层
- 不是任务调度框架
- 不是高层分析算法层

它更像：

- 分布式运行时抽象
- 分布式数据结构组织层
- 上层 package 可以复用的并行基础设施层

## 第 3 层：`Communicator` 统一串行和 MPI 运行

这层是 Xyce 并行抽象里最值得先读懂的一层。

### `Communicator` 提供统一接口

[N_PDS_Comm.h](../../vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_Comm.h) 定义了抽象类 `Communicator`。

它统一了这些能力：

- 进程身份：`procID()`、`numProc()`、`isSerial()`
- 规约：`scanSum()`、`sumAll()`、`maxAll()`、`minAll()`
- 广播与点对点通信：`bcast()`、`send()`、`recv()`、`iRecv()`、`waitAll()`
- 打包与解包：`pack()`、`unpack()`
- 同步：`barrier()`
- 访问底层机器通信对象：`comm()`

这说明：

- Xyce 上层不会在每个调用点直接写裸 `MPI_Bcast`、`MPI_Allreduce`
- 它更希望通过统一抽象收敛串行与并行差异

### 串行和 MPI 版本通过工厂切换

在 [N_PDS_EpetraHelpers.C](../../vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_EpetraHelpers.C) 中，`createPDSComm(...)` 会根据编译配置和输入 communicator 决定：

- MPI build 时创建 `EpetraMPIComm`
- 否则创建 `EpetraSerialComm`

这意味着：

- 上层代码只依赖抽象接口
- 具体是串行实现还是 MPI 实现，由底层工厂和 build 配置决定

### `EpetraSerialComm` 是一个 no-op 并行后端

[N_PDS_EpetraSerialComm.h](../../vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_EpetraSerialComm.h) 表现出一个很清楚的设计：

- `procID() == 0`
- `numProc() == 1`
- `isSerial() == true`
- `bcast()/send()/recv()/barrier()` 大多退化为空操作或简单返回

这层设计的好处是：

- 上层逻辑尽量不需要到处写 `if serial` / `if mpi`
- 同一套主流程代码可以在不同并行模式下工作

## 第 4 层：`Manager` 组织分布式 map、accessor 和 graph

如果 `Communicator` 解决的是“如何通信”，那 `Manager` 更接近在解决：

- 通信服务和分布式数据结构如何统一托管

### `Manager` 自己持有 communicator

[N_PDS_Manager.h](../../vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_Manager.h) 里能看到：

- `Manager` 内部有 `pdsComm_`
- 构造时会通过 `createPDSComm(...)` 得到具体 communicator

所以：

- `Manager` 是上层 package 拿到并行基础设施的核心对象

### `Manager` 维护多类并行 map

这个类里有一组很重要的 map id：

- `SOLUTION`
- `SOLUTION_OVERLAP`
- `STATE`
- `STORE`
- `LEADCURRENT`
- `JACOBIAN`
- 以及多种 linear / nonlinear 相关 map

这说明并行层不是只维护“一个总 map”，而是会针对不同数据角色维护不同的分布式视图。

### `Manager` 也维护 `GlobalAccessor` 和 `Graph`

除了 `ParMap`，它还维护：

- `GlobalAccessor`
- `Linear::Graph`

这说明它的责任不只是“知道 rank 有几个”，而是要真正支撑：

- 全局到本地的索引访问
- 分布式矩阵/图结构组织

这一层已经非常接近电路模拟器的大规模分布式实现核心了。

## 第 5 层：分布式数据结构才是 Xyce 并行的主战场

这一层是最容易被“线程池思维”忽略，但在 Xyce 里最该重视的一层。

### 这里的重点不是线程数，而是数据分布

如果用共享内存线程池思维看并行，很容易首先关注：

- 有几个 worker
- 队列怎么调度
- 锁怎么减小开销

但 Xyce 并行的关键更像是：

- 数据属于哪个 rank
- 全局编号如何映射到本地编号
- overlap 区域如何处理
- 图和矩阵结构如何跨进程组织

这背后的核心问题是：

- distributed ownership
- global/local mapping
- overlap / halo
- collective reduction

### 为什么这一层更值得优先学

因为电路模拟器真正要扩到大规模并行时，瓶颈和复杂度往往不在“线程池写没写漂亮”，而在：

- 分布式数据划分是否合理
- 通信和装配边界如何组织
- 全局和局部对象如何保持一致

所以从 Xyce 项目里学习并行，最大的增量通常不是再学一个线程池，而是学这种分布式思维。

## 第 6 层：MPI 生命周期与辅助规约

这一层继续往底层走，关注真正的 MPI 生命周期和更贴近 MPI 的辅助实现。

### `MPI_Init` 从哪里开始

在 [N_PDS_EpetraMPIComm.C](../../vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_EpetraMPIComm.C) 的 `createMPIComm()` 中：

- 先调用 `MPI_Initialized`
- 如果还没初始化，则执行 `MPI_Init`
- 如果外部已经初始化过，就复用现有 MPI 环境

这说明 Xyce 的设计不仅支持自己启动 MPI，也考虑了嵌入已有 MPI 宿主环境的情况。

### `MPI_Finalize` 从哪里结束

在 [N_CIR_Xyce.C](../../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.C) 的 `Xyce_exit()` 中：

- 会做 `MPI_Barrier`
- 需要时调用 `MPI_Abort`
- 最后 `MPI_Finalize`

这意味着：

- 并行环境的建立和结束都是顶层生命周期的一部分

### `N_PDS_MPI.h` 提供更贴近 MPI 的辅助能力

[N_PDS_MPI.h](../../vendor/Xyce-7.10.0/src/ParallelDistPKG/N_PDS_MPI.h) 和对应实现负责更底层的 MPI 辅助抽象，例如：

- MPI datatype traits
- 自定义 reduce/op 支持
- 复杂数据类型的规约辅助

这一层说明：

- Xyce 不只是“把 MPI 调一下”
- 它还为上层复杂数据与规约需求补了一层自己的适配

## 第 7 层：线程级并行主要落在 solver backend

到了这一层，才真正进入“更像多线程”的部分。

### 主干源码里几乎看不到显式线程调度

对 `src/` 进行关键词搜索后，最值得记住的事实是：

- 没有形成大规模应用层 `#pragma omp` 主线
- 没有围绕 `std::thread` 的主干并发框架

这说明：

- Xyce 应用层主叙事并不是共享内存线程调度

### OpenMP 的主要落点是 Trilinos / Kokkos / solver backend

在 [tps.cmake](../../vendor/Xyce-7.10.0/cmake/tps.cmake) 中：

- 会先看 `Kokkos_DEVICES` 是否启用了 `OPENMP`
- 如果启用了，就要求 `find_package(OpenMP REQUIRED)`

在 [trilinos-beta.cmake](../../vendor/Xyce-7.10.0/cmake/trilinos/trilinos-beta.cmake) 和 [trilinos-MPI-beta.cmake](../../vendor/Xyce-7.10.0/cmake/trilinos/trilinos-MPI-beta.cmake) 中又可以看到：

- `ShyLU-Basker requires OpenMP`
- `OMP_NUM_THREADS` 需要设置到合理值

这几乎已经把线程级并行的真正位置点明了：

- 它主要属于 solver backend 能力
- 不是 Xyce 顶层业务层自己构建的通用线程框架

### `IRSolver` 负责把 solver backend 接入上层求解流程

在 [N_LAS_IRSolver.C](../../vendor/Xyce-7.10.0/src/LinearAlgebraServicesPKG/N_LAS_IRSolver.C) 中可以看到：

- `type_ == "SHYLU_BASKER"` 时选择 `ShyLUBasker`
- `type_ == "BASKER"` 时选择 `Basker`

所以这一层的结构关系是：

- Xyce 上层提供 solver 选择入口
- 真正的线程级并行能力由后端 solver 决定和承载

## 把这几层压缩成一张图

如果把上面的 8 层再压缩成一张结构图，大致可以记成：

```text
项目级语义
  -> Xyce 的 parallel 首先是 MPI distributed-memory

顶层主流程
  -> Circuit::Simulator 在初始化早期创建 parallelManager_
  -> 并把并行服务注入 analysis / topology / linear system / device

并行抽象层
  -> ParallelDistPKG
  -> Communicator / Manager / ParMap / GlobalAccessor / Graph

MPI 与分布式运行时
  -> EpetraMPIComm / EpetraSerialComm / N_PDS_MPI
  -> MPI_Init / collective / mapping / reduce / finalize

线程级并行后端
  -> Trilinos / Kokkos / OpenMP / Basker / ShyLU-Basker
```

这张图是这份笔记最核心的产出。

## 对初学者最有益的学习顺序

如果你刚学完：

- 内存池
- 线程池

那最值得采用的顺序不是先找线程池实现，而是：

1. 先读顶层 `Simulator` 如何创建和传播 `parallelManager_`
2. 再读 `ParallelDistPKG` 的 `Communicator + Manager + ParMap`
3. 再理解分布式 map / graph / overlap 这一层的数据组织
4. 最后再回来看 Trilinos / Basker / ShyLU-Basker 的线程级并行

为什么这条顺序更有益：

- 它能把你从共享内存线程思维切到分布式并行思维
- 也更符合 Xyce 真实的并行结构

## 当前结论

这轮重构后，可以把 Xyce 并行内容总结成下面 4 句：

1. Xyce 的并行首先是项目级的 MPI distributed-memory 设计选择。
2. 顶层 `Simulator` 在生命周期很早的位置接入并行环境，并把并行服务传播给多个主干子系统。
3. `ParallelDistPKG` 是 Xyce 自己实现的并行基础设施层，重点是 communicator、manager、map、graph 和规约，而不是线程池。
4. 真正的线程级并行主要下沉在 Trilinos / Kokkos / Basker / ShyLU-Basker 这样的 solver backend。

## 下一步还要继续追踪什么

按照“自顶向下继续下钻”的方式，后续最自然的 3 步是：

1. 单独读 `ParallelDistPKG/N_PDS_ParMap.*` 与 `N_PDS_GlobalAccessor.*`
   目标：把分布式数据结构层补完整。
2. 追 `Topology` 和 `Linear::System` 如何消费这些 map 和 graph
   目标：看并行基础设施怎样真正进入装配与求解。
3. 单开一份“solver backend 线程级并行”笔记
   目标：把 `OpenMP / Kokkos / Basker / ShyLU-Basker` 这条底层支线独立讲清楚。
