# 08-interfaces

## 功能

本目录记录 Xyce 被外部程序驱动、嵌入或包装时涉及的接口知识和源码实现。

本目录重点是 C++ interface、C ABI、动态库、Python `ctypes` 和 REST wrapper，不负责一般 GUI 或网表转换工具综述。

## 本级模块职责

- `README.md`：说明接口专题职责和阅读顺序。
- `01-interface-concepts-for-cpp-beginners.md`：面向 C++ 初学者的 interface 入门。
- `02-xyce-c-python-interface-code-reading.md`：Xyce C/Python interface 的源码实现导读。

## 使用建议

先读 `01-interface-concepts-for-cpp-beginners.md` 建立 API/ABI、动态库、C wrapper 和 opaque pointer 概念，再读 `02-xyce-c-python-interface-code-reading.md`。

## 当前约定

- 通用 interface 知识与 Xyce 源码导读分开维护。
- 后续若实际构建 `libxycecinterface.so` 或验证 Python 驱动，应新增独立验证记录，不把执行日志写入 README。
