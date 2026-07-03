# 非 EDA 的 C++ 方向清单

记录日期：2026-07-03

## 目标

这份文档只回答一个问题：

```text
基于我当前的背景，
除了 EDA 之外，
还有哪些 C++ 方向值得认真考虑？
```

当前背景默认是：

- 有 `C++` 基础，愿意继续强化
- 在读 `Xyce` 这类中大型工程
- 做过设计自动化方向研究
- 会一定的 `Python`
- 懂一点机器学习
- 模拟电路仍然是初学者

## 先说结论

如果不把自己锁死在 EDA 里，你最值得优先考虑的，不是所有 `C++` 岗，而是下面这些和你现有积累最能迁移的方向：

1. 科学计算 / CAE / 仿真软件 / solver / HPC
2. 编译器 / 程序分析 / LLVM / MLIR / 性能工具链
3. 高性能基础设施 / 分布式系统 / 工程平台型 `C++`
4. AI 系统 / 推理运行时 / GPU 计算软件

这四类的共同点是：

- 都认可 `C++ + Linux + 调试 + 性能 + 工程系统`
- 都比“纯业务后端”更吃你现在的积累
- 都允许你把“设计自动化 + 工程代码 + 数值/性能直觉”讲成优势

## 方向 1：科学计算 / CAE / 仿真软件 / HPC

### 为什么适合你

这是离你当前积累最近、同时又不被 EDA 锁死的一条路。

你现在在 `Xyce` 里学到的很多东西，本质上都能迁移：

- solver 流程
- 数值计算直觉
- 性能分析
- 大型 `C++` 工程阅读
- 验证与回归

而且这类岗位并不要求你必须有深模拟电路背景。

### 典型工作内容

- 求解器开发
- 并行计算
- CPU / GPU 性能优化
- benchmark / profiling / regression
- 数值模块与工程软件集成

### 你会用到的关键词

- `C++`
- MPI / OpenMP / CUDA / SYCL
- sparse / solver / FEM / CFD / multiphysics
- profiling
- scalability
- scientific computing

### 当前市场信号

截至 **2026-07-03**，这类岗位依然很活跃。

- Siemens 的 `CFD Software Engineer` 公开要求里直接提到高水平 `C++` 和并行编程。  
  https://jobs.sw.siemens.com/leuven-bel/cfd-software-engineer/AD04337CDC0749A59B810FFD17F6457E/job/
- Siemens 的 `Manufacturing Solver Developer (Casting)` 公开要求里提到 `FEM`、数值方法、`C++`、`Python`。  
  https://jobs.sw.siemens.com/bucharest-rom/manufacturing-solver-developer-casting/84BAF40F062E48B29310F66892E2FC78/job/
- Synopsys 在 **2026-05-07** 发布的 `HPC Software Engineer` 明确写了 MPI、CUDA/HIP/SYCL、profiling、benchmark、C/C++、build/CI。  
  https://careers.synopsys.com/job/canonsburg/hpc-software-engineer/44408/87085299616

### 匹配度判断

这是我认为你当前最值得认真保留的非 EDA 主备线。

## 方向 2：编译器 / 程序分析 / LLVM / MLIR / 工具链

### 为什么适合你

这条路和“设计自动化研究背景”其实很相通，因为它同样重视：

- 中间表示
- 变换与优化
- 大型 `C++` 工程
- 性能与 correctness
- 工具链思维

如果你愿意补一点编译原理和 LLVM/MLIR，这会是一条很强的泛化路径。

### 典型工作内容

- IR 设计
- optimization pass
- code generation
- compiler runtime
- program analysis
- performance tooling

### 你会用到的关键词

- LLVM
- MLIR
- compiler backend
- codegen
- optimization
- IR
- tooling

### 当前市场信号

截至 **2026-07-03**，NVIDIA 这类岗位仍然大量强调：

- 强 `C/C++`
- 编译器背景
- 性能分析
- CPU/GPU 架构理解

例如：

- `Compiler Optimization Engineer - LLVM`  
  https://nvidia.wd5.myworkdayjobs.com/en-US/NVIDIAExternalCareerSite/job/Compiler-Optimization-Engineer---LLVM_JR2014377
- `Deep Learning Compiler Engineer - CUDA`  
  https://nvidia.wd5.myworkdayjobs.com/en-US/NVIDIAExternalCareerSite/job/Deep-Learning-Compiler-Engineer---CUDA_JR2010731
- `Senior Software Engineer, Deep Learning - MLIR TRT`  
  https://nvidia.wd5.myworkdayjobs.com/en-US/NVIDIAExternalCareerSite/job/Senior-Software-Engineer--Deep-Learning---MLIR-TRT_JR2009329

### 匹配度判断

这条路上限很高，但补课成本会比 CAE / solver 路线更明显。

如果你愿意围绕“通用 C++ 项目”去做 parser / IR / static analysis / pass 这类项目，它会非常加分。

## 方向 3：高性能基础设施 / 分布式系统 / 工程平台型 C++

### 为什么适合你

这条路比 solver 和 compiler 更通用，但依然能保留你最值钱的工程能力：

- Linux
- `C++`
- 性能
- 自动化
- 构建与测试
- 大型系统调试

如果你不想过度绑定某个学科或行业，这是一个很稳的备选方向。

### 典型工作内容

- 高吞吐后台服务
- 分布式任务调度
- 计算平台基础设施
- benchmark / observability / reliability
- 工程工具与流水线

### 你会用到的关键词

- distributed systems
- concurrency
- IPC / RPC
- performance
- scalability
- CI/CD
- Linux systems

### 当前市场信号

截至 **2026-07-03**：

- Siemens 的 `Distributed Systems Software Engineer` 公开要求里提到 `C/C++`、`Python`、Linux 开发，以及面向可扩展性和性能优化的代码。  
  https://jobs.sw.siemens.com/thessaloniki-grc/distributed-systems-software-engineer-fixed-term/A0446B39E09244568D1E1779030D054F/job/
- Siemens 还有偏高性能研发解法的 `Senior C++ Software Engineer`，强调分布式系统和高性能研发方案。  
  https://jobs.sw.siemens.com/shannon-irl/senior-c-software-engineer-leading-edge-high-performance-rd-solutions-hybrid-model-shannon/E1BCDA9E1BA2486B96BBE775D3BE4668/job/

### 匹配度判断

这条路对“非领域绑定”的效果最好，但如果项目完全不带数值、工具链或工程分析味道，和你现有积累的衔接会弱一点。

## 方向 4：AI 系统 / 推理运行时 / GPU 计算软件

### 为什么适合你

你“懂一点机器学习”，但更重要的是你能把自己放在系统软件位置，而不是模型研究位置。

也就是说，更适合你的不是“去卷算法岗”，而是：

- AI compiler
- inference runtime
- GPU software
- performance engineering

### 典型工作内容

- runtime / kernel / library 优化
- graph lowering
- 编译和执行栈优化
- 大规模计算性能调优

### 你会用到的关键词

- C/C++
- CUDA
- runtime
- compiler
- kernel optimization
- MLIR / XLA / Triton / TVM

### 当前市场信号

截至 **2026-07-03**：

- NVIDIA 的 `Senior Software Engineer, CUDA Core Libraries` 强调面向 `C++` / Python 开发者的 GPU 计算核心库。  
  https://nvidia.wd5.myworkdayjobs.com/en-US/NVIDIAExternalCareerSite/job/Senior-Software-Engineer--CUDA-Core-Libraries_JR2014754
- NVIDIA 的 `AI Computing Software Development Engineer, TensorRT-LLM` 强调 `C/C++`、软件设计、性能分析和测试设计。  
  https://nvidia.wd5.myworkdayjobs.com/en-US/NVIDIAExternalCareerSite/job/AI-Computing-Software-Development-Engineer--TensorRT-LLM_JR2002840
- NVIDIA 的 `AI Developer Technology Engineer - New College Grad 2026` 公开描述里提到 `C/C++`、算法和提升大规模计算应用在 GPU 上的性能。  
  https://nvidia.wd5.myworkdayjobs.com/en-US/NVIDIAExternalCareerSite/job/AI-Developer-Technology-Engineer--Financial-Sector---New-College-Grad-2026_JR2013803

### 匹配度判断

这条路的吸引力很高，但你要小心不要被“我懂一点机器学习”误导。

真正适合你的切法是：

- 以系统 / 编译 / runtime / 性能工程身份切入
- 不是以模型训练或算法研究身份切入

## 哪些方向不建议你现在优先押注

基于你当前背景，我不太建议你把主线优先放在：

- 纯业务后端 `C++`
- 深嵌入式 / 驱动 / BSP
- 纯图形图像 / 游戏引擎
- 强模拟设计经验前置的岗位

原因不是这些方向绝对不行，而是：

- 它们和你当前积累的迁移效率不如上面四条
- 你需要额外补很多“与现有资产弱相关”的东西

## 最实用的排序建议

如果今天就要做求职策略排序，我会建议你这样排：

1. `EDA`
2. `科学计算 / CAE / solver / HPC`
3. `编译器 / 程序分析 / LLVM / MLIR`
4. `高性能基础设施 / 分布式系统`
5. `AI 系统 / runtime / GPU 软件`

这不是“行业鄙视链”，而是单纯按你当前积累的迁移效率来排。

## 一句话判断

除了 EDA 之外，你最值得认真保留的 C++ 方向，不是泛泛的所有软件岗位，而是：

```text
以“工程系统 + 性能 + 数值/工具链” 为核心的方向
```

这会比你直接把自己投进普通 `C++` 岗海里，更容易打出差异化。
