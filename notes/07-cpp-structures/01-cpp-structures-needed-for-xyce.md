# cpp structures needed for Xyce

记录日期：2026-06-03

## 这次读了哪些文件

这次不是为了追一条新的仿真主线，而是为了回头总结“阅读 Xyce 真正需要的 C++ 结构”。这次选的文件都尽量来自前几阶段已经见过的地方：

- [src/CircuitPKG/N_CIR_Xyce.h](../../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.h)
- [src/CircuitPKG/N_CIR_Xyce.C](../../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.C)
- [src/AnalysisPKG/N_ANP_RegisterAnalysis.C](../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_RegisterAnalysis.C)
- [src/AnalysisPKG/N_ANP_AnalysisManager.C](../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AnalysisManager.C)
- [src/LoaderServicesPKG/N_LOA_Loader.h](../../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_Loader.h)
- [src/NonlinearSolverPKG/N_NLS_Manager.h](../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_Manager.h)
- [src/NonlinearSolverPKG/N_NLS_Manager.C](../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_Manager.C)
- [src/NonlinearSolverPKG/N_NLS_NonLinearSolver.h](../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_NonLinearSolver.h)
- [src/NonlinearSolverPKG/N_NLS_NonLinearSolver.C](../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_NonLinearSolver.C)
- [src/DeviceModelPKG/Core/N_DEV_DeviceMaster.h](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/Core/N_DEV_DeviceMaster.h)
- [src/TopoManagerPKG/N_TOP_CktNode_Dev.h](../../vendor/Xyce-7.10.0/src/TopoManagerPKG/N_TOP_CktNode_Dev.h)
- [src/TopoManagerPKG/N_TOP_CktNode_Dev.C](../../vendor/Xyce-7.10.0/src/TopoManagerPKG/N_TOP_CktNode_Dev.C)

## 这次带着什么问题去读

第七阶段的大纲要求不是去补“所有 C++ 语法”，而是只补阅读 Xyce 真正需要的那些结构：

- 继承关系和抽象接口
- 工厂模式和注册机制
- 指针、引用和对象所有权
- package / 头文件组织
- 模板只在必要时理解

所以这次的目标不是“学完 C++”，而是回答：

```text
面对 Xyce 这种大型工程时，
哪些 C++ 结构一定要先看懂，
哪些可以暂时不深挖
```

## 当前结论先写在前面

对当前阶段最重要的 C++ 认识，可以先压缩成这几句：

- Xyce 大量使用“抽象接口 + Manager / 工厂”来隔离具体实现
- 很多对象是“先声明指针，后注册 / 后初始化”，所以 raw pointer 很多
- `*_fwd.h` 和前向声明是为了降低大头文件之间的耦合
- 模板在 Xyce 里确实存在，但第一轮阅读只需要抓住像 `DeviceMaster<T>` 这种“通用框架复用”用途
- 不要一看到很多 `*ptr_`、`Factory`、`Traits`、模板就觉得这是一堆高级技巧；它们大多是在解决大型工程里的模块组织问题

## 第一类：接口继承为什么这么多

如果前几阶段已经读过 nonlinear solver 和 loader 这一条线，这一类结构其实已经反复出现过。

先看：

- [N_NLS_NonLinearSolver.h](../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_NonLinearSolver.h)

这里的 `NonLinearSolver` 不是一个“完整算法类”，而是：

```text
抽象基类 / 公共接口
```

它里面有很多纯虚函数或面向派生类的接口，比如：

- `solve(...)`
- `setOptions(...)`
- `setTranOptions(...)`
- `setAnalysisMode(...)`
- `getNumIterations()`

这说明作者想表达的是：

```text
“nonlinear solver”是一个角色，
而不是一个具体算法
```

具体算法可以是：

- `DampedNewton`
- `NOX` interface
- `TwoLevelNewton`

所以这一类继承的本质不是“为了炫技”，而是为了把：

- 调度层
- 统一接口
- 具体算法

分开。

### 这一类结构怎么读

以后你遇到类似类时，先不要立刻看所有成员函数。先判断：

1. 它是不是抽象接口
2. 哪些函数是“派生类必须实现”的
3. 哪些函数是“基类帮大家统一做的”

比如在：

- [N_NLS_NonLinearSolver.C](../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_NonLinearSolver.C)

里，`rhs_()`、`jacobian_()`、`newton_()` 这些公共逻辑，正是“基类统一做”的那一部分。

所以第七阶段第一个该建立的习惯是：

```text
先判断“接口”和“实现”谁是谁
```

而不是一上来就把所有函数当作同一层次。

## 第二类：Manager 不是算法类，而是调度类

前几阶段你已经见过：

- `AnalysisManager`
- `Nonlinear::Manager`
- `DeviceMgr`

这些名字都很像“什么都管一点”，容易让人觉得混乱。其实它们的共同特点是：

```text
Manager 更多是调度 / 注册 / 生命周期管理，
不是底层算法实现
```

例如：

- [N_NLS_Manager.h](../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_Manager.h)

这里的 `Manager` 持有：

- `NonLinearSolver * nonlinearSolver_`
- `Linear::SolverFactory *`
- `Linear::PrecondFactory *`
- 一堆 option block

这说明它主要做的是：

1. 选一种 solver
2. 把依赖注册进去
3. 统一暴露 `solve()`

而不是“自己就是 Newton 迭代算法”。

### 为什么这类类很重要

因为大型工程里，真正难的通常不是“写一个算法函数”，而是：

- 什么时候创建它
- 它和哪些系统互相注册
- 什么时候替换它
- 谁负责释放它

Manager 类就是专门干这个的。

所以以后读 Xyce 里的 `*Manager`，第一反应应该是：

```text
先看它持有哪些对象、注册哪些对象、转发哪些对象
```

而不是先看它有没有复杂数值代码。

## 第三类：工厂和注册机制，是 Xyce 最常见的解耦方式

如果说前面“接口继承”是在解决“统一角色”，那工厂 / 注册就是在解决：

```text
谁来决定创建哪一个具体实现
```

### 先看 analysis 的注册

最直接的例子是：

- [N_ANP_RegisterAnalysis.C](../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_RegisterAnalysis.C)

这里的：

- `registerAnalysisFactory(...)`

会依次注册：

- `registerDCSweepFactory(...)`
- `registerACFactory(...)`
- `registerTransientFactory(...)`
- ...

这一类代码的本质不是“运行分析”，而是：

```text
把“有哪些分析类型可以被创建”先登记好
```

所以当你后面看到 `AnalysisManager::allocateAnalysisObject(...)` 不是直接 `new Transient(...)`，而是从 registry 里找 creator，这就不再奇怪了。

### 再看 device 侧的工厂 / 模板

device 这一侧更典型的例子是：

- [N_DEV_DeviceMaster.h](../../vendor/Xyce-7.10.0/src/DeviceModelPKG/Core/N_DEV_DeviceMaster.h)

在这里你已经见过：

- `DeviceMaster<T>::addInstance(...)`

这段代码的关键不是模板语法本身，而是它在做一件非常工程化的事：

```text
把“各种器件实例创建的公共骨架”抽出来复用
```

它里面通用处理了：

- 找 model
- 缺省 model 的处理
- instance map 去重
- 真正 `new InstanceType(...)`
- 把 instance 存回 model / master

这说明：

- Xyce 不是每种器件都手写一整套“找 model + 建实例 + 加入列表”的代码
- 而是把共性提到模板框架里

### 这一类结构怎么读

对当前阶段，你不必深挖所有模板语法细节。只要先抓住：

1. 哪部分是“可变的类型”
2. 哪部分是“所有器件共用的流程”

所以对于 `DeviceMaster<T>`，现在最重要的理解是：

```text
模板参数 T 代表“某一类具体 device”，
而 addInstance() 代表“所有 device 共用的实例化流程”
```

这就够了。

## 第四类：raw pointer 很多，不代表设计一定很乱

Xyce 是老牌大型 C++ 工程，所以你会看到非常多：

- `SomeType * ptr_`
- 手工 `new`
- 手工 `delete`

这对现在习惯现代 C++ 的人来说很容易不适应，但第一轮阅读时先不要急着下判断。

先看两个非常典型的例子。

### 例子 1：`AnalysisManager` 自己管理生命周期

在：

- [N_ANP_AnalysisManager.C](../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AnalysisManager.C)

里，析构函数会手工 `delete`：

- `nonlinearEquationLoader_`
- `workingIntgMethod_`
- `dataStore_`
- `stepErrorControl_`

而 `initializeSolverSystem(...)` 里还会先删掉旧对象，再重建新对象。

这说明这里的 ownership 很明确：

```text
AnalysisManager 拥有这些对象
AnalysisManager 负责它们的重建和释放
```

所以虽然写法是 raw pointer，但不是“谁都能乱管”。

### 例子 2：`CktNode_Dev` 的过渡所有权

在：

- [N_TOP_CktNode_Dev.h](../../vendor/Xyce-7.10.0/src/TopoManagerPKG/N_TOP_CktNode_Dev.h)
- [N_TOP_CktNode_Dev.C](../../vendor/Xyce-7.10.0/src/TopoManagerPKG/N_TOP_CktNode_Dev.C)

里可以看到一个很有代表性的 ownership 变化：

1. 构造时 `instanceBlock_ = new InstanceBlock(...)`
2. `instantiate()` 之后把它交给 `DeviceMgr` 去创建 `deviceInstance_`
3. 然后 `delete instanceBlock_; instanceBlock_ = 0;`

这是一种很典型的“过渡对象”模式：

- `instanceBlock_` 只在实例化前有意义
- 一旦变成真正 `deviceInstance_`，它就应该被销毁

所以这里最值得学的不是“指针语法”，而是：

```text
对象在流程中的生命周期阶段
```

### 这个阶段怎么处理 raw pointer

当前阶段别急着把它们全脑补成 bug 源。先问：

1. 谁创建它
2. 谁释放它
3. 它是不是允许被替换 / 重新分配

如果这三件事清楚，阅读就不会乱。

## 第五类：什么时候用引用，什么时候用指针

这一点在 Xyce 里其实很有规律。

### 传构造依赖时，经常用引用

比如：

- `NonlinearEquationLoader` 的构造函数

在：

- [N_LOA_NonlinearEquationLoader.h](../../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_NonlinearEquationLoader.h)

里可以看到它接收的是：

- `TimeIntg::DataStore &`
- `Loader &`
- `DeviceMgr &`
- `WorkingIntegrationMethod &`

这种写法通常意味着：

```text
这些依赖在构造时必须存在
而且这个类不拥有它们
```

### 需要延后注册、可重新绑定时，经常用指针

反过来看：

- [N_NLS_NonLinearSolver.h](../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_NonLinearSolver.h)

这里很多成员是指针，并通过 `register...()` 函数后续设置：

- `registerLinearSystem(...)`
- `registerAnalysisManager(...)`
- `registerNonlinearEquationLoader(...)`

这种写法通常意味着：

```text
对象在构造时还不完整，
需要后续装配
```

这跟前面几阶段看到的初始化流程是对上的：

- Xyce 的很多大对象不是构造函数一次性拼好
- 而是先创建，再逐步注册 subsystem

所以以后看到：

- 构造函数参数里的引用
- 成员里的原始指针

你可以先这样粗分：

- 引用：当下就必须有
- 指针：后面再挂上去，或者允许替换

这已经能帮你看懂很多设计意图。

## 第六类：`*_fwd.h` 和前向声明，是大工程降耦合的基本手段

这个点在 [N_CIR_Xyce.h](../../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.h) 和 [N_NLS_Manager.h](../../vendor/Xyce-7.10.0/src/NonlinearSolverPKG/N_NLS_Manager.h) 里都很明显。

你会看到一长串：

- `#include <N_ANP_fwd.h>`
- `#include <N_IO_fwd.h>`
- `#include <N_LAS_fwd.h>`
- ...

这类 `*_fwd.h` 的意义不是“神秘技巧”，而是：

```text
头文件里如果只需要声明“有这么个类”，
就不要把对方完整头文件拉进来
```

这样做的好处很直接：

1. 减少编译依赖
2. 降低大头文件之间的耦合
3. 避免头文件互相 include 成网

### 什么时候必须 include 完整定义

如果一个头文件里只是：

- 成员指针
- 成员引用
- 函数参数声明

通常前向声明就够了。

但如果要：

- 按值持有对象
- 调用内联成员函数需要完整类型
- 继承某个类

那就往往需要 include 真正的定义头。

所以以后你看到一个头文件开头大量 `*_fwd.h`，不用紧张，它通常说明作者在刻意控制依赖。

## 第七类：模板在第一轮阅读里只要抓“用途”，不用先抓“技巧”

这个点单独强调一下。

像：

- `DeviceMaster<T>`
- 某些 factory / traits 组合

会让人一下子以为“模板很多，我先去补模板元编程”。这通常不是当前最有效的做法。

对第一轮阅读，更好的办法是：

```text
先问：这个模板是在复用什么流程？
而不是先问：这里用了哪些高级语法技巧？
```

以 `DeviceMaster<T>` 为例，当前阶段知道这些就够了：

- `T` 表示某一类具体 device
- 公共实例化流程被模板复用
- 真正的差异落在 `InstanceType`、`ModelType`、`Traits` 这些类型别名和静态接口上

等你以后真的想读透某一类复杂器件，再回头细看模板细节，效率会更高。

## 当前阶段最值得保留的阅读习惯

第七阶段最重要的，不是记住某个语法定义，而是建立下面这套阅读顺序：

1. 先分清是接口类、实现类，还是 Manager / 调度类
2. 遇到工厂和注册，先看“谁决定创建哪个具体类”
3. 遇到很多指针，先理 ownership 和生命周期
4. 遇到模板，先看它复用了什么通用流程
5. 遇到一堆 `*_fwd.h`，意识到这是依赖管理，不是功能逻辑

如果这五件事能做到，阅读大型 C++ 工程会轻松很多。

## 这一阶段先不用深挖的东西

当前阶段可以暂时不急着深挖：

- 所有模板语法细节
- `Teuchos::RCP` 的完整语义和实现
- 所有 STL 容器接口
- 多重继承和很边角的 C++ 语法

只要这些东西没有直接挡住你理解当前调用链，就先不必展开。

第七阶段的原则应该是：

```text
只补“阻碍阅读 Xyce 的那部分 C++”
而不是把 Xyce 当成一本 C++ 语法教材
```

## 现在可以做的自检

你可以先试着回答这四个问题：

1. `NonLinearSolver` 更像“具体算法类”还是“抽象接口 + 公共框架”？
2. `Manager` 这类类，在 Xyce 里更偏“数值算法实现”还是“调度 / 生命周期管理”？
3. `DeviceMaster<T>::addInstance(...)` 里的模板，解决的是“语法炫技”问题，还是“通用实例化流程复用”问题？
4. 在 `CktNode_Dev` 里，为什么 `instanceBlock_` 可以在实例化之后马上删除？
