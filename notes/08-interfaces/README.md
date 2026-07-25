# 接口与外部驱动专题

本目录用于记录 Xyce 被外部程序驱动、嵌入或包装时涉及的接口层。

建议阅读顺序：

1. `01-interface-concepts-for-cpp-beginners.md`
   - 面向 C++ 初学者，从 API/ABI、动态库、C wrapper、opaque pointer、Python FFI 等概念入门。

2. `02-xyce-c-python-interface-code-reading.md`
   - 回到 Xyce 源码，按 `Simulator -> C interface -> CMake target -> Python ctypes -> REST` 的顺序读实现。

当前关注：

- interface 的高层概念；
- C++ class 与 C ABI 的边界；
- 动态库 interface；
- Python `ctypes` wrapper；
- REST 示例；
- 后续可能的交互式控制原型。
