# Xyce C/Python interface 是什么

## 1. 一句话解释

Xyce C/Python interface 是 Xyce 提供的一层“外部程序驱动接口”：

```text
外部程序
  -> C ABI 函数
    -> Xyce::Circuit::Simulator
      -> 初始化/运行/分段推进/查询/修改参数/关闭
```

它不是 Xyce 的普通命令行模式，也不是 GUI。

普通命令行模式是：

```text
Xyce netlist.cir
```

C/Python interface 的目标是让 Python、C、Matlab、Simulink、VPI、REST 服务等外部程序把 Xyce 当成一个库来调用。

## 2. 为什么需要 C interface

Xyce 内部是 C++ 工程，顶层对象是：

```text
Xyce::Circuit::Simulator
```

但很多外部语言不能直接稳定调用 C++ class，因为 C++ ABI、name mangling、对象生命周期和异常处理都比较复杂。

所以 Xyce 在外面包了一层 C ABI：

```text
utils/XyceCInterface/N_CIR_XyceCInterface.h
```

这层接口用 `extern "C"` 暴露简单函数，例如：

```text
xyce_open()
xyce_initialize()
xyce_runSimulation()
xyce_simulateUntil()
xyce_getCircuitValue()
xyce_setCircuitParameter()
xyce_close()
```

Python 再通过 `ctypes` 加载这个 C interface 动态库。

## 3. Python interface 是什么

Python wrapper 位于：

```text
utils/XyceCInterface/xyce_interface.py.cmake
```

它的核心动作是：

```text
加载 libxycecinterface.so
创建 xycePtr
调用 C 函数
把 Python 参数转成 C 参数
把 C 返回值转回 Python
```

例如 Python wrapper 中有：

```text
initialize(args)
runSimulation()
simulateUntil(requestedTime)
```

这说明 Python interface 不是重新实现仿真器，而是薄薄一层胶水。

## 4. REST 示例

Xyce 还提供了一个 REST 示例：

```text
utils/XyceCInterface/XyceRest.py
```

它把 Python interface 包装成 HTTP endpoint，例如：

```text
/xyce_initialize
/xyce_simulateuntil
/xyce_run
/xyce_getsimtime
/xyce_getcircuitvalue
/xyce_setcircuitparameter
/xyce_close
```

这说明 Xyce 官方源码中已经存在“会话式外部驱动”的雏形。

## 5. 它能做什么

适合：

```text
外部程序启动 Xyce session
初始化一个 netlist
运行完整仿真
分段推进 transient
查询当前仿真时间
查询某些变量/measure/参数
修改已经存在的 circuit/device parameter
关闭仿真对象
```

特别适合：

```text
Python/Jupyter 交互实验
co-simulation
Simulink/VPI 联合仿真
REST 服务封装
交互式原型验证
```

## 6. 它不能直接等价于 Spectre interactive

它不是完整的 Spectre-like interactive mode。

当前接口不应默认理解为支持：

```text
动态新增/删除器件
动态改变拓扑
任意 alter netlist
重新 include PDK model
会话内任意切换 DC/AC/TRAN/NOISE
完整 waveform viewer
完整 GUI
```

其中 `simulateUntil()` 更偏向 transient/mixed-signal co-simulation 的分段推进，不是所有分析类型的通用 interactive 控制。

## 7. 当前本项目安装状态

当前最小静态安装中已经有：

```text
out/xyce-7.10-serial-release/include/N_CIR_XyceCInterface.h
out/xyce-7.10-serial-release/share/xyce_interface.py
out/xyce-7.10-serial-release/share/XyceRest.py
```

但当前没有发现：

```text
libxycecinterface.so
```

原因之一是源码中 `xycecinterface` target 是：

```text
add_library(xycecinterface EXCLUDE_FROM_ALL)
```

且当前 Xyce 构建是：

```text
BUILD_SHARED_LIBS=OFF
```

所以后续如果要真正跑 Python interface，需要新增或调整构建层，显式构建可被 Python `ctypes` 加载的 `libxycecinterface.so`。

## 8. 后续验证建议

建议新增：

```text
FV010: Xyce C interface shared build
FV011: Python ctypes wrapper run resistor netlist
FV012: Python simulateUntil RC transient
FV013: Python getCircuitValue / setCircuitParameter 最小验证
```

这条路线比直接在 Xyce 主程序中实现 `-interactive` 更稳。
