# C++ 语言学习模块

这个目录专门用于沉淀本项目阅读过程中遇到的 C++ 语法、语义和常见易错点。

组织原则：

- 优先记录“读 Xyce 源码时真的会碰到”的语法点，而不是一次性铺开整本 C++ 教材。
- 每个主题尽量按“本质问题、最小例子、常见误区、自测问题”四段来写。
- 能和项目代码建立对应关系时，优先补一条“在源码里通常长什么样”。

## 当前主题

- `syntax-basics.md`：声明、定义、头文件、匿名命名空间等基础语法
- `xyce-reading-structures.md`：阅读 Xyce 真正需要的接口、Manager、工厂、模板和 ownership 结构

## 后续建议补充

- `references-and-pointers.md`：引用、指针、`const` 与参数传递
- `classes-and-lifetime.md`：类、构造函数、析构函数与对象生命周期
- `containers-and-strings.md`：`std::vector`、`std::string` 与常见遍历方式
- `inheritance-and-interfaces.md`：继承、虚函数与抽象接口
- `templates-and-auto.md`：模板、`auto`、`decltype` 与类型推导

## 使用方式

后续如果我们在对话里讲了新的语法点，可以继续往这个模块里增补：

1. 先把结论沉淀到对应主题文档。
2. 再补最小示例和一两个判断题。
3. 如果该语法在 Xyce 里很常见，再附一条源码阅读提示。
