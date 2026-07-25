# Xyce C/Python interface 源码实现导读

## 1. 这篇笔记回答什么

上一篇 `01-interface-concepts-for-cpp-beginners.md` 讲的是通用 interface 知识。

这篇回到 Xyce 源码，回答：

```text
Xyce 的 C/Python interface 在代码里是怎么实现的？
```

核心结论：

```text
Xyce::Circuit::Simulator
  -> C wrapper: N_CIR_XyceCInterface.{h,C}
    -> dynamic library target: xycecinterface
      -> Python ctypes wrapper: xyce_interface.py
        -> REST wrapper: XyceRest.py
```

## 2. 源码入口地图

相关文件：

```text
vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.h
vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.C
vendor/Xyce-7.10.0/utils/XyceCInterface/N_CIR_XyceCInterface.h
vendor/Xyce-7.10.0/utils/XyceCInterface/N_CIR_XyceCInterface.C
vendor/Xyce-7.10.0/utils/XyceCInterface/CMakeLists.txt
vendor/Xyce-7.10.0/utils/XyceCInterface/xyce_interface.py.cmake
vendor/Xyce-7.10.0/utils/XyceCInterface/XyceRest.py
```

安装后相关文件：

```text
out/xyce-7.10-serial-release/include/N_CIR_XyceCInterface.h
out/xyce-7.10-serial-release/share/xyce_interface.py
out/xyce-7.10-serial-release/share/XyceRest.py
```

当前最小静态安装没有发现：

```text
libxycecinterface.so
```

这意味着当前安装包含接口头文件和 wrapper 脚本，但还没有可以让 Python `ctypes` 加载的动态库。

## 3. 最内层：Xyce::Circuit::Simulator

Xyce 的顶层仿真器对象是：

```cpp
Xyce::Circuit::Simulator
```

它定义在：

```text
src/CircuitPKG/N_CIR_Xyce.h
```

这个类提供了外部驱动仿真所需的生命周期方法：

```text
run()
initialize()
initializeEarly()
initializeLate()
setWorkingDirectory()
runSimulation()
simulateUntil()
finalize()
simulationComplete()
getTime()
getFinalTime()
getCircuitValue()
setCircuitParameter()
obtainResponse()
```

这些方法说明，Xyce 内部已经不是只有“一次性命令行执行”这一种形态。它可以被拆成：

```text
初始化
运行
分段推进
查询
修改参数
关闭
```

这就是 C/Python interface 能存在的基础。

## 4. 为什么不直接把 Simulator 暴露给 Python

不能直接把 C++ class 暴露给 Python，主要有几个问题：

```text
C++ name mangling
C++ ABI 不稳定
class 内存布局复杂
异常不能安全跨语言传播
STL 类型跨边界风险大
对象生命周期需要被外部语言管理
```

所以 Xyce 选择了更稳的方式：

```text
对外暴露 C ABI
内部再转回 C++ Simulator
```

## 5. C interface 头文件

文件：

```text
utils/XyceCInterface/N_CIR_XyceCInterface.h
```

文件注释已经说明它的目的：

```text
C callable functions to link to Xyce's C++ interface
```

并说明它让其它程序，例如 Python，通过动态链接 C library 调用 Xyce。

核心形式：

```cpp
#ifdef __cplusplus
extern "C" {
#endif

void xyce_open(void** ptr);
void xyce_close(void** ptr);
int xyce_initialize(void** ptr, int narg, char** argv);
int xyce_runSimulation(void** ptr);
int xyce_simulateUntil(void** ptr, double requestedUntilTime, double* completedUntilTime);
double xyce_getTime(void** ptr);
double xyce_getFinalTime(void** ptr);
double xyce_getCircuitValue(void** ptr, char* paramName);
bool xyce_setCircuitParameter(void** ptr, char* paramName, double value);

#ifdef __cplusplus
}
#endif
```

这里最重要的设计点有两个：

1. `extern "C"`：导出 C ABI，避免 C++ name mangling；
2. `void** ptr`：用 opaque pointer 保存内部 C++ `Simulator` 对象。

## 6. opaque pointer 在 Xyce 中怎么用

从接口形式可以推断：

```text
xyce_open(void** ptr)
```

会创建内部对象，并把对象地址放入 `ptr`。

后续所有函数都接收：

```text
void** ptr
```

这相当于：

```text
你给我一个 handle，我内部知道它是 Xyce::Circuit::Simulator。
```

外部程序不需要知道 `Simulator` 的 C++ 定义，也不应该直接访问里面的字段。

这是 C wrapper 包装 C++ class 的典型方法。

## 7. 生命周期对应关系

Xyce C interface 可以按生命周期理解：

| 阶段 | C interface | C++ Simulator |
|---|---|---|
| 创建对象 | `xyce_open()` | `new Simulator` |
| 初始化 | `xyce_initialize()` | `Simulator::initialize()` |
| 早期初始化 | `xyce_initialize_early()` | `Simulator::initializeEarly()` |
| 后期初始化 | `xyce_initialize_late()` | `Simulator::initializeLate()` |
| 完整运行 | `xyce_runSimulation()` | `Simulator::runSimulation()` |
| 分段推进 | `xyce_simulateUntil()` | `Simulator::simulateUntil()` |
| 查询是否结束 | `xyce_simulationComplete()` | `Simulator::simulationComplete()` |
| 查询时间 | `xyce_getTime()` | `Simulator::getTime()` |
| 查询变量/参数 | `xyce_getCircuitValue()` | `Simulator::getCircuitValue()` |
| 修改参数 | `xyce_setCircuitParameter()` | `Simulator::setCircuitParameter()` |
| 关闭对象 | `xyce_close()` | `finalize/delete` |

这张表是理解 Xyce interface 的主线。

## 8. CMake 如何构建接口库

文件：

```text
utils/XyceCInterface/CMakeLists.txt
```

关键内容：

```cmake
add_library( xycecinterface EXCLUDE_FROM_ALL )
target_sources( xycecinterface PRIVATE N_CIR_XyceCInterface.C PUBLIC N_CIR_XyceCInterface.h )
target_link_libraries( xycecinterface XyceLib )
```

含义：

1. `xycecinterface` 是一个 library target；
2. 它由 `N_CIR_XyceCInterface.C` 和 `.h` 组成；
3. 它链接到 `XyceLib`，也就是 Xyce 主体库；
4. `EXCLUDE_FROM_ALL` 表示它不一定默认被普通 `all` 构建目标构建。

安装规则：

```cmake
install( TARGETS xycecinterface DESTINATION lib OPTIONAL)
install( FILES N_CIR_XyceCInterface.h DESTINATION include OPTIONAL)
install( FILES ${CMAKE_CURRENT_BINARY_DIR}/xyce_interface.py DESTINATION share OPTIONAL)
install( FILES XyceRest.py DESTINATION share OPTIONAL)
```

所以理想安装结果应该包含：

```text
include/N_CIR_XyceCInterface.h
lib/libxycecinterface.so
share/xyce_interface.py
share/XyceRest.py
```

当前项目最小安装没有 `libxycecinterface.so`，说明后续需要专门构建这个 target 或新建 shared/interface 构建层。

## 9. Python wrapper 怎么接 C interface

文件：

```text
utils/XyceCInterface/xyce_interface.py.cmake
```

开头注释：

```text
Python wrapper on Xyce via Xyce library mode via ctypes
```

它使用：

```python
from ctypes import *
from ctypes.util import *
```

然后寻找动态库：

```python
libName = find_library('xycecinterface')
```

如果找不到，就尝试：

```text
libxycecinterface.so
```

加载成功后，它保存：

```python
self.lib
self.xycePtr
```

`self.lib` 是动态库对象；`self.xycePtr` 是 Xyce C interface 中的 `void*` handle。

## 10. Python initialize()

Python wrapper 的 `initialize(args)` 做了一个典型 FFI 转换：

```text
Python list[str]
  -> c_char_p array
    -> char** argv
      -> xyce_initialize()
```

这一步的意义是：模拟命令行参数。

普通命令行：

```bash
Xyce circuit.cir
```

Python interface：

```python
xyce.initialize(["circuit.cir"])
```

内部会补一个程序名：

```python
args.insert(0, "xyce_interface.py")
```

然后传给 C interface。

## 11. Python runSimulation() 与 simulateUntil()

完整运行：

```python
xyce.runSimulation()
```

对应：

```text
xyce_runSimulation()
Simulator::runSimulation()
```

分段推进：

```python
xyce.simulateUntil(1e-9)
```

对应：

```text
xyce_simulateUntil()
Simulator::simulateUntil()
```

`simulateUntil()` 的语义不是“任意 interactive 命令”，而是把当前仿真推进到指定时间。它主要适合 transient / mixed-signal co-simulation。

## 12. REST 示例

文件：

```text
utils/XyceCInterface/XyceRest.py
```

它把 Python wrapper 再封装成 HTTP endpoint。

典型 endpoint：

```text
/xyce_initialize
/xyce_getsimtime
/xyce_getfinaltime
/xyce_getcircuitvalue
/xyce_setcircuitparameter
/xyce_simulateuntil
/xyce_run
/xyce_close
```

这层结构是：

```text
HTTP request
  -> Flask route
    -> xyce_interface method
      -> C interface function
        -> Xyce::Circuit::Simulator
```

它不是生产级服务设计说明，但非常适合作为“外部会话式驱动 Xyce”的源码例子。

## 13. 当前项目的实际状态

当前安装已有：

```text
out/xyce-7.10-serial-release/include/N_CIR_XyceCInterface.h
out/xyce-7.10-serial-release/share/xyce_interface.py
out/xyce-7.10-serial-release/share/XyceRest.py
```

当前没有：

```text
out/xyce-7.10-serial-release/lib/libxycecinterface.so
```

原因与当前构建有关：

```text
BUILD_SHARED_LIBS=OFF
xycecinterface EXCLUDE_FROM_ALL
```

因此，这些文件现在更像“接口源码和脚本已安装”，但还不能直接用 Python `ctypes` 跑通。

## 14. 如果后续要验证，应该怎么做

建议新增一个独立构建层：

```text
build/xyce-7.10-serial-shared-interface/
out/xyce-7.10-serial-shared-interface/
```

目标：

```text
BUILD_SHARED_LIBS=ON
构建 xycecinterface target
安装 libxycecinterface.so
用 Python wrapper 跑最小 netlist
```

验证顺序：

```text
FV010: 找到/构建 libxycecinterface.so
FV011: Python 加载 xyce_interface.py
FV012: Python initialize + runSimulation 跑 resistor
FV013: Python simulateUntil 跑 RC transient
FV014: Python getCircuitValue 查询 V(out)
FV015: Python setCircuitParameter 修改简单参数
```

## 15. 它和源码 interactive mode 的关系

Xyce 本体没有 Spectre-like interactive shell。

但 C/Python interface 可以作为 interactive-like 原型的基础：

```text
Python REPL / Jupyter
  -> initialize netlist
  -> simulateUntil
  -> getCircuitValue
  -> setCircuitParameter
  -> close
```

这比直接修改 `src/Xyce.C` 增加 `-interactive` 更稳，因为它先复用 Xyce 已经提供的外部驱动接口。

等 C/Python interface 的边界摸清后，再考虑 C++ `XyceInteractive` 原型，风险会小得多。

## 16. 阅读 Xyce interface 的主线

建议按这个顺序读：

```text
1. N_CIR_Xyce.h
   看 Simulator 对外有哪些生命周期方法

2. N_CIR_XyceCInterface.h
   看 C ABI 暴露了哪些函数

3. N_CIR_XyceCInterface.C
   看 C 函数如何转调 Simulator 方法

4. CMakeLists.txt
   看 xycecinterface 怎么构建、怎么安装

5. xyce_interface.py.cmake
   看 Python ctypes 如何加载动态库并包装 C 函数

6. XyceRest.py
   看 REST 如何把 Python wrapper 变成 HTTP session
```

这条路径刚好从内到外：

```text
C++ core -> C ABI -> shared library -> Python FFI -> REST
```
