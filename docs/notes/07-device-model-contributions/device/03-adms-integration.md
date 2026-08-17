# ADMS 接入方式

记录日期：2026-06-04

## 这篇的定位

这一篇专门回答一个容易混淆的问题：

```text
ADMS 到底是一类器件，
还是一种把器件模型接进 Xyce 的方式？
```

结论先写在前面：

```text
ADMS 不是器件类别，
而是一条“模型描述 -> 生成 Xyce 可编译 C++ 代码”的接入路线。
```

## 建议的代码入口顺序

这一篇建议按下面顺序看：

1. 先看 [src/DeviceModelPKG/ADMS](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/ADMS)
2. 再看 [utils/ADMS](../../../vendor/Xyce-7.10.0/utils/ADMS)
3. 然后看：
   - [generate_ADMS.sh](../../../vendor/Xyce-7.10.0/utils/generate_ADMS.sh)
   - [install_ADMS.sh](../../../vendor/Xyce-7.10.0/utils/install_ADMS.sh)
4. 最后看：
   - [CMakeLists.txt](../../../vendor/Xyce-7.10.0/CMakeLists.txt)
   - [XyceSuperBuild.cmake](../../../vendor/Xyce-7.10.0/XyceSuperBuild.cmake)
   - [INSTALL.md](../../../vendor/Xyce-7.10.0/INSTALL.md)

这个顺序的逻辑是：

```text
先看结果文件
-> 再看 Xyce 自己提供的模板和脚本
-> 最后确认外部生成器到底从哪里来
```

## ADMS 本身是什么意思

在这个上下文里，`ADMS` 通常指：

```text
Automatic Device Model Synthesizer
```

你可以先把它理解成：

```text
一个把高层器件模型描述
转换成仿真器可用 C / C++ 代码的模型代码生成器
```

对 Xyce 来说，更实用的理解是：

```text
ADMS = 一条 Verilog-A / 模型描述
-> Xyce 器件实现代码
的生成接入路线
```

## 为什么要有 ADMS 这条路线

因为很多工业 compact model：

- 公式非常大
- 参数非常多
- 版本非常多
- 常常本来就以更高层的模型描述形式维护

如果全部手工改写成 Xyce 风格的 `OpenModels` C++，成本会很高，也容易出错。

所以更合理的方式是：

1. 模型先用更适合表达公式的高层形式维护
2. 再用生成工具把它翻译成 Xyce 能编译的 C++ 代码

这就是为什么 `ADMS` 更像“接入方式”，而不是“模型物理类别”。

## src/DeviceModelPKG/ADMS 里放的是什么

先看：

- [src/DeviceModelPKG/ADMS](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/ADMS)

这里你会看到很多文件：

- [N_DEV_ADMSbsim6.C](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/ADMS/N_DEV_ADMSbsim6.C)
- [N_DEV_ADMSbsimcmg.C](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/ADMS/N_DEV_ADMSbsimcmg.C)
- [N_DEV_ADMSvbic13.C](../../../vendor/Xyce-7.10.0/src/DeviceModelPKG/ADMS/N_DEV_ADMSvbic13.C)

这一层很容易误会成“ADMS 生成器源码”，但其实不是。

更准确地说，这里放的是：

```text
已经生成好的模型实现结果文件
```

也就是：

- 这些文件已经是 Xyce 可编译的 `C++`
- 它们是生成流程的产物
- 不是生成器本体

## utils/ADMS 里放的是什么

再看：

- [utils/ADMS](../../../vendor/Xyce-7.10.0/utils/ADMS)

这里的角色就不一样了。

这一层更像 Xyce 自己为 ADMS 路线准备的：

- 模板
- 示例
- 生成脚手架

代表文件包括：

- [adms.implicit.xml](../../../vendor/Xyce-7.10.0/utils/ADMS/adms.implicit.xml)
- [xyceBasicTemplates_nosac.xml](../../../vendor/Xyce-7.10.0/utils/ADMS/xyceBasicTemplates_nosac.xml)
- [xyceHeaderFile_nosac.xml](../../../vendor/Xyce-7.10.0/utils/ADMS/xyceHeaderFile_nosac.xml)
- [xyceImplementationFile_nosac.xml](../../../vendor/Xyce-7.10.0/utils/ADMS/xyceImplementationFile_nosac.xml)

所以这一层可以理解成：

```text
Xyce 侧的模板和集成规则
```

而不是完整的 ADMS 编译器本体。

## 生成器本体在哪里

要回答“真正把模型描述转换成 C++ 的程序在哪”，就要再往外看一层。

先看：

- [CMakeLists.txt](../../../vendor/Xyce-7.10.0/CMakeLists.txt)

这里会去找：

```text
admsXml
```

也就是说，Xyce 构建时默认认为系统里存在一个外部工具：

```text
admsXml
```

再看：

- [XyceSuperBuild.cmake](../../../vendor/Xyce-7.10.0/XyceSuperBuild.cmake)
- [INSTALL.md](../../../vendor/Xyce-7.10.0/INSTALL.md)

这里可以看到，Xyce 的这条能力依赖外部项目：

```text
Qucs/ADMS
```

所以更准确的结论是：

```text
真正的 ADMS 生成器源码不在这个 release 包里完整 vendor 下来，
Xyce 通过外部的 admsXml / Qucs-ADMS 项目来使用它。
```

## 整条链怎么理解

你可以先把 ADMS 路线压成下面这条链：

```text
模型描述（常见是 Verilog-A 风格）
+ Xyce 的 ADMS 模板
+ 外部 admsXml 生成器
->
生成 N_DEV_ADMS*.C / .h
->
进入 src/DeviceModelPKG/ADMS
->
编译进 Xyce
```

这就是为什么 `ADMS` 既不像 `OpenModels` 那样完全手写，也不像 `EXTSC` 那样靠外部运行时接口，而是位于两者之间：

- 模型最终进了 Xyce 内部
- 但实现方式依赖一条生成路线

## 它和 OpenModels 最本质的差别

可以先这样简单区分：

### OpenModels

- 更像手工整理、手工维护的 Xyce 风格器件实现
- 适合拿来学习 `Traits / Model / Instance / Master`
- 可读性通常更适合作为第一次学习入口

### ADMS

- 更像由模型描述生成出来的实现结果
- 常常带有更强的“生成器代码味道”
- 更适合在你已经理解主线之后，再把它当成“模型接入方式”去理解

所以这也是为什么我们前面先学：

- `Capacitor`
- `Diode`
- `MOSFET_B4`

而不是一开始就读 `ADMSbsim6`。

## 这一篇最想让你先吃下来的本质

你以后只要看到 `src/DeviceModelPKG/ADMS/`，先不要把它当成“新的物理模型大类”，而应该先这样理解：

```text
这里更多是在说明：
这些模型是通过 ADMS 这条生成路线接进 Xyce 的
```

换句话说：

- `MOS`、`BJT`、`Diode` 这些是模型类型
- `ADMS`、`OpenModels`、`EXTSC` 这些更偏实现/接入方式

## 现在可以做的自检

你可以先试着回答这两个问题：

1. 为什么 `src/DeviceModelPKG/ADMS/` 里的 `N_DEV_ADMS*.C` 不应该被理解成“ADMS 生成器源码”？
2. 你现在会怎么区分 `utils/ADMS/` 和外部 `Qucs/ADMS` 各自扮演的角色？
