# C++ 初学者的 interface 入门

## 1. 为什么要学 interface

你已经做过简单线程池动态库，这其实已经碰到了 interface 的核心问题：

```text
别人不关心线程池内部怎么调度线程；
别人只关心能调用哪些函数、传什么参数、返回什么结果、谁负责释放资源。
```

这个“外部能依赖的边界”就是 interface。

在大型 C++ 项目中，interface 不是一个单独语法点，而是一组工程概念：

```text
接口设计
编译边界
链接边界
动态库边界
语言边界
进程边界
版本兼容边界
```

Xyce 的 C/Python interface 正好适合用来学习这些概念，因为它同时涉及：

```text
C++ class
C ABI
shared library
Python ctypes
REST wrapper
外部程序驱动仿真器
```

## 2. interface 的核心定义

最朴素地说：

```text
interface = 一组被外部使用者依赖的约定
```

这个约定包括：

- 可以调用什么；
- 参数是什么；
- 返回什么；
- 出错怎么办；
- 对象什么时候创建；
- 对象什么时候销毁；
- 内存谁分配；
- 内存谁释放；
- 哪些行为保证稳定；
- 哪些细节属于内部实现，外部不应依赖。

所以 interface 不是“写几个函数声明”这么窄。函数声明只是 interface 的一部分。

## 3. API、ABI、implementation 的区别

这三个词经常混在一起，但需要分清。

### 3.1 API

API 是 Application Programming Interface。

它回答：

```text
源代码层面，别人应该怎么调用我？
```

例如：

```cpp
int add(int a, int b);
```

使用者看到头文件，就知道可以这样写：

```cpp
int c = add(1, 2);
```

这就是 API。

### 3.2 ABI

ABI 是 Application Binary Interface。

它回答：

```text
编译成二进制之后，调用方和被调用方如何在机器层面互相理解？
```

ABI 包括：

- 函数符号名；
- 调用约定；
- 参数如何传递；
- 返回值如何传递；
- struct/class 内存布局；
- vtable 布局；
- 异常如何传播；
- 标准库类型布局；
- 动态库导出符号。

API 稳定不代表 ABI 稳定。

例如 C++ 中这个函数：

```cpp
std::string getName();
```

源代码看起来很简单，但 ABI 可能受编译器版本、标准库版本、编译选项影响。

### 3.3 implementation

implementation 是内部实现。

例如：

```cpp
int add(int a, int b)
{
  return a + b;
}
```

调用者只需要依赖：

```cpp
int add(int, int);
```

不应该依赖它内部怎么写。

## 4. 头文件和动态库分别提供什么

一个动态库通常有两部分：

```text
头文件：告诉编译器怎么调用
库文件：提供真正实现
```

Linux 下常见：

```text
foo.h
libfoo.so
```

编译时：

```text
编译器看 foo.h，检查函数声明和类型
链接器找 libfoo.so，确认函数实现存在
运行时动态加载器再找到 libfoo.so
```

如果只有头文件，没有库文件：

```text
能编译部分源文件，但最终链接或运行会失败
```

如果只有库文件，没有头文件：

```text
不知道该怎么正确调用，除非手写声明或用动态符号查询
```

这就是为什么 Xyce 当前安装里虽然有：

```text
N_CIR_XyceCInterface.h
xyce_interface.py
XyceRest.py
```

但没有：

```text
libxycecinterface.so
```

就还不能直接跑 Python `ctypes` wrapper。

## 5. 静态库和动态库的 interface 区别

### 5.1 静态库

静态库通常是：

```text
libfoo.a
```

特点：

- 链接时把代码合入最终可执行文件；
- 运行时不需要再找这个库；
- 对外部语言动态加载不方便；
- 更像“编译期复用”。

### 5.2 动态库

动态库通常是：

```text
libfoo.so
```

特点：

- 运行时加载；
- 多个程序可共享同一个库；
- Python `ctypes`、插件系统、REST 服务后端常需要它；
- 需要处理运行时库路径、ABI 兼容、符号导出。

对 Xyce C/Python interface 来说，Python 需要加载：

```text
libxycecinterface.so
```

所以它天然偏向动态库方式。

## 6. C++ interface 的常见形式

### 6.1 普通函数

```cpp
int add(int a, int b);
```

简单，但能力有限。

### 6.2 class interface

```cpp
class ThreadPool
{
public:
  void submit(Task task);
  void shutdown();
};
```

适合 C++ 内部使用，但跨动态库、跨编译器、跨语言时要小心 ABI。

### 6.3 abstract base class

```cpp
class ISolver
{
public:
  virtual ~ISolver() = default;
  virtual bool solve() = 0;
};
```

适合插件或 C++ 模块间解耦，但 vtable ABI 仍然是 C++ ABI 问题。

### 6.4 C wrapper

```cpp
extern "C" {
  void* solver_create();
  int solver_solve(void* solver);
  void solver_destroy(void* solver);
}
```

这是很多 C++ 库给 Python、C、Rust、Go、Matlab 等外部语言提供接口时的经典做法。

Xyce C interface 就是这种思路。

## 7. 为什么跨语言时常用 C ABI

C++ 函数名会发生 name mangling。

例如源代码：

```cpp
int add(int, int);
```

编译后符号名可能变成类似：

```text
_Z3addii
```

不同编译器、不同平台可能不同。

而 C ABI 更稳定：

```cpp
extern "C" int add(int, int);
```

这样导出的符号名通常就是：

```text
add
```

Python `ctypes` 这类工具才容易查找和调用。

所以如果你的 C++ 库要给外部语言用，常见做法是：

```text
C++ 内部保持 class 和复杂结构
对外暴露一层简单 C API
```

## 8. opaque pointer：把 C++ 对象藏在 void*

跨语言接口经常这样设计：

```cpp
extern "C" {
  void open(void** handle);
  int run(void** handle);
  void close(void** handle);
}
```

这里的 `void*` 或 `void**` 是 opaque pointer。

意思是：

```text
外部程序只拿到一个不透明句柄；
外部程序不知道里面是什么；
内部实现可以把它 cast 回真正的 C++ 对象。
```

例如内部可能是：

```cpp
auto* sim = static_cast<Xyce::Circuit::Simulator*>(*ptr);
```

这个设计的好处是：

- C API 不暴露 C++ class 定义；
- ABI 更稳定；
- 外部语言只需要保存一个 handle；
- 内部实现可以演化。

Xyce 的 `xyce_open(void** ptr)`、`xyce_initialize(void** ptr, ...)`、`xyce_close(void** ptr)` 就是这类设计。

## 9. interface 设计最容易踩的坑

### 9.1 谁分配，谁释放

如果库里分配内存，调用方释放，可能出问题。

尤其在 Windows 或不同 runtime 下：

```text
库 A 用自己的 allocator 分配
程序 B 用另一个 runtime free
```

可能崩。

稳妥做法：

```text
谁分配，谁提供释放函数
```

例如：

```cpp
char* get_message();
void free_message(char*);
```

### 9.2 不要跨 C ABI 抛 C++ 异常

C++ 异常穿过 C/Python 边界通常很危险。

更稳妥：

```text
C++ 内部 catch
转成错误码或错误字符串
```

例如：

```cpp
int status = run(handle);
```

### 9.3 不要轻易在 C ABI 暴露 STL 类型

不推荐：

```cpp
extern "C" std::vector<double> get_data();
extern "C" std::string get_name();
```

因为这些是 C++ 类型，不是真正的 C ABI 友好类型。

更稳妥：

```cpp
int get_data(double* buffer, int buffer_size);
```

或者：

```cpp
const char* get_name();
```

但字符串生命周期要讲清楚。

### 9.4 版本兼容

一旦外部程序依赖你的接口，接口就变成承诺。

如果你改了：

```text
函数名
参数顺序
返回值语义
结构体布局
错误码定义
内存释放规则
```

外部程序可能就坏了。

这就是 interface 设计要保守的原因。

## 10. interface 的层级地图

可以把 interface 分成几层：

```text
同一进程内 C++ interface
  class / virtual function / template

动态库 C ABI interface
  extern "C" / void* handle / error code

外部语言 binding
  Python ctypes / pybind11 / cffi / SWIG

进程间 interface
  CLI / file / pipe / socket / REST / RPC

用户级 workflow interface
  command line / notebook / GUI / scripts
```

Xyce 里这些层都能看到影子：

```text
Xyce::Circuit::Simulator       -> C++ interface
N_CIR_XyceCInterface.h         -> C ABI interface
xyce_interface.py              -> Python ctypes binding
XyceRest.py                    -> REST process/service interface
Xyce executable                -> CLI interface
```

## 11. 用线程池动态库类比

假设你做过一个线程池动态库。

如果只给 C++ 用，可能写：

```cpp
class ThreadPool
{
public:
  explicit ThreadPool(int n);
  void submit(std::function<void()> f);
  void shutdown();
};
```

如果要给 Python 用，通常不会直接暴露这个 class，而是包一层：

```cpp
extern "C" {
  void threadpool_create(void** handle, int n);
  int threadpool_submit_print_task(void** handle, const char* message);
  void threadpool_shutdown(void** handle);
  void threadpool_destroy(void** handle);
}
```

这和 Xyce 很像：

```text
ThreadPool class                 -> Xyce::Circuit::Simulator
threadpool_create/destroy         -> xyce_open/xyce_close
threadpool_submit/run             -> xyce_initialize/runSimulation/simulateUntil
threadpool_get_status             -> xyce_getTime/getCircuitValue
```

## 12. 学习接口时要问的 10 个问题

以后读任何 interface，都可以问：

1. 这个接口服务谁？
2. 调用方和被调用方在同一个进程吗？
3. 它是源码 API，还是二进制 ABI？
4. 它暴露 C++ 类型，还是 C 友好类型？
5. 对象怎么创建？
6. 对象怎么销毁？
7. 内存谁分配，谁释放？
8. 错误怎么报告？
9. 是否允许重复调用？
10. 哪些能力是承诺，哪些只是内部实现？

带着这 10 个问题读 Xyce C/Python interface，会比直接盯着函数名更清楚。
