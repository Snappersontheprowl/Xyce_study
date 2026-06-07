# 笔记目录

这个目录用于存放按学习阶段和专题整理的笔记。

当前目录结构按学习顺序组织：

- `01-overview/`：整体导航地图与高层结构
- `02-startup/`：程序启动流程与顶层 `Simulator`
- `03-netlist-and-circuit-build/`：`netlist` 解析与电路构建
- `04-device-trace/`：普通器件到实例化、装配的纵向追踪
- `05-analysis-flow/`：按“基础 / 进阶”两层组织分析调度专题
  - `01-basic/`：`.OP / .DC / .TRAN` 的入口、注册、生命周期、基础设施初始化
  - `02-advanced/`：`AC / NOISE / HB / MPDE` 的调度地图
  - `03-sensitivity/`：灵敏度作为附着在主分析上的能力层，其调度与生命周期
- `06-solver-and-assembly/`：按“基础 / 进阶”两层组织方程与求解专题
  - `01-basic/`：电路 DAE 的建立与 `DC / transient` 求解骨架
  - `02-advanced/`：`AC / NOISE / HB / MPDE` 的进阶求解路线
  - `03-sensitivity/`：解敏感度、输出敏感度、direct / adjoint 的数学与求解
- `07-device-model-contributions/`：从求解器继续下钻，研究器件如何贡献 `Q/F/B/dQdx/dFdx`
  - 其中 `05-mosfet-b4/` 是 `B4` 的独立子专题
  - 其中 `device/` 是器件家族地图和 `ADMS` 接入方式的扩展阅读
  - `05-mosfet-b4/`：把 `MOSFET_B4` 单独拆成一条复杂 compact model 学习支线

其中需要单独沉淀但不属于主线顺序的横向内容，放到 `docs/` 下维护：

- `docs/cpp/`：阅读 Xyce 时真正会遇到的 C++ 结构和语法补充

命名约定：

- 文件名使用阶段内顺序编号，例如 `01-startup-flow.md`
- 记录日期放在文件内容中，不再放在文件名里
- 同一专题下的多篇笔记按阅读顺序递增编号

每份笔记尽量保持简洁，至少回答这些问题：

- 这次读了哪些文件
- 带着什么问题去读
- 当前得出了什么结论
- 下一步还要继续追踪什么
