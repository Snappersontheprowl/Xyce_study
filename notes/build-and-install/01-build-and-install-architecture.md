# Xyce 的编译与安装架构

记录日期：2026-07-22

## 这篇的目标

本篇先不执行安装，只回答一个总览问题：

- 像 Xyce 这样依赖数值计算框架的大型 C++ 项目，应该怎样理解其编译、安装和验证过程。

学习时最重要的结论是：Xyce 的构建不是“在源码目录执行一次 `make`”这么简单，而是一个由**工具链一致性、第三方数值栈、Xyce 功能开关、独立构建目录、安装与测试**组成的闭环。

## 读了哪些文件

- `vendor/Xyce-7.10.0/INSTALL.md`
- `vendor/Xyce-7.10.0/CMakeLists.txt`
- `vendor/Xyce-7.10.0/XyceSuperBuild.cmake`
- `vendor/Xyce-7.10.0/cmake/config.cmake`
- `vendor/Xyce-7.10.0/src/CMakeLists.txt`
- `vendor/Xyce-7.10.0/gitlab-ci/buildTestInstallXyce.yml`

## 总体构建图

```text
系统工具链
  C/C++（以及可选 Fortran）编译器、CMake、构建器、flex、bison
        |
        v
第三方数值栈（必须与工具链、并行模式匹配）
  BLAS / LAPACK + SuiteSparse(AMD) + Trilinos
  + 可选 FFTW、MPI、ADMS 等
        |
        v
Xyce 的 CMake 配置
  选择串行或 MPI；定位 Trilinos；选择可选功能；生成解析器源码
        |
        v
独立 build 目录
  编译各 package -> libxyce -> Xyce 可执行文件
        |
        v
独立 install 前缀
  bin/Xyce、lib/libxyce.*、include/、share/ 等
        |
        v
冒烟测试 + 回归测试
```

这里的箭头是依赖关系，不是源代码运行时调用关系。大型工程把这两者分开，是为了让同一份源码能对应多种互不污染的构建：例如 `Release` / `Debug`、串行 / MPI、带 / 不带 ADMS 插件支持。

## 为什么不能直接编译 Xyce

### 核心外部依赖是 Trilinos

Xyce 的核心线性代数和求解能力依托 Trilinos。`src/CMakeLists.txt` 中的 `XyceLib` 直接链接 `Trilinos::all_selected_libs`；因此 Xyce 配置阶段必须先找到一套已安装、组件齐全的 Trilinos。

而 Trilinos 本身又依赖或使用：

- BLAS / LAPACK：基础稠密数值计算；
- SuiteSparse 中的 AMD：稀疏矩阵重排序；
- 可选 MPI：分布式内存并行；
- 可选 Fortran：Trilinos 的部分代码会使用，虽然 Xyce 本身不直接要求 Fortran。

所以正确的依赖方向是：

```text
BLAS/LAPACK + SuiteSparse(AMD) [+ MPI]
  -> Trilinos（只启用 Xyce 需要的包）
  -> Xyce
```

不能把“系统碰巧装了某个 Trilinos”默认当成可用条件。Xyce 7.10 的安装文档要求 Trilinos 至少为 14.4，并明确提醒：更高版本未经过严格验证。实际工程中还必须确认其启用了 Xyce 所需的 Epetra、NOX、Amesos/KLU、Sacado、Teuchos 等包。

### 编译器与并行模式必须成对一致

Trilinos 和 Xyce 不是两个可以随意混搭的二进制包。至少要保持下面两项一致：

| 构建维度 | Trilinos | Xyce | 不能混用的原因 |
| --- | --- | --- | --- |
| C/C++ 编译器及 ABI | 例如同一套 GCC | 同一套 GCC | C++ 标准库、ABI、链接选项必须兼容 |
| 并行模式 | 串行或 MPI | 相同模式 | MPI 头文件、库和 Trilinos 的通信层必须匹配 |

例如，串行 Xyce 应使用串行 Trilinos；MPI Xyce 应使用由 `mpicc` / `mpicxx`（以及通常的 `mpifort`）构建的 MPI Trilinos。两个安装前缀也应独立保留。

## Xyce 7.10 的构建入口：优先 CMake

本地发布版同时保留 `configure.ac` / `Makefile.am`，但 `INSTALL` 已明确说明 Autotools 在 7.10 中弃用；实际应把 `INSTALL.md` 和顶层 `CMakeLists.txt` 作为构建入口。

顶层 CMake 的关键形态是：

```text
CMake configure
  -> cmake/config.cmake：探测依赖和功能开关
  -> src/CMakeLists.txt：flex/bison 生成解析器源码
  -> 各 src/*PKG 子目录：加入编译单元
  -> XyceLib
  -> Xyce 可执行文件
```

其中 `flex` 和 `bison` 并非普通可有可无的开发工具：它们会从表达式和反应解析器的 `.l` / `.yxx` 输入生成 C++ 源文件，因此是正常源码构建的必需项。

## 两条可选路线

### 路线 A：分层构建（推荐用于学习和可控开发）

先各自从源码构建并安装 SuiteSparse 和 Trilinos，再单独配置 Xyce：

```text
SuiteSparse build/install
  -> Trilinos build/install
  -> Xyce build/install
```

优点是依赖版本、编译参数和错误归属都清晰；也便于以后只重编 Xyce，而不反复重编大型 Trilinos。当前学习仓库最适合采用这条路线。

### 路线 B：`Xyce_USE_SUPERBUILD=ON`

顶层 `XyceSuperBuild.cmake` 使用 CMake `ExternalProject_Add` 自动拉取、构建 SuiteSparse、Trilinos、ADMS，最后构建 Xyce。

它适合希望快速得到一套完整隔离环境的情形，但不应把它误解成“永远最稳的默认方案”。本地 7.10 的 SuperBuild 中固定的是较早的 Trilinos `trilinos-release-12-12-1`，而 `INSTALL.md` 的常规 CMake 指引针对的是 Trilinos 14.4 及以上；两套版本策略并不完全一致。对于本仓库的源码学习和可复现构建，优先按 `INSTALL.md` 分层构建，并把精确版本和配置命令记录下来。

## 推荐的目录隔离方式

源码、构建产物和安装结果各自独立：

```text
vendor/Xyce-7.10.0/                 # 不写入构建产物；源码快照
build/xyce-7.10-serial-release/     # CMake cache、对象文件、日志
out/xyce-7.10-serial-release/       # 安装前缀；bin/Xyce 等
```

后续若要构建 MPI 或调试版，另开目录：

```text
build/xyce-7.10-mpi-release/        -> out/xyce-7.10-mpi-release/
build/xyce-7.10-serial-debug/       -> out/xyce-7.10-serial-debug/
```

不要在同一个 CMake build 目录切换编译器、MPI 开关、共享库开关或 `Debug`/`Release`。这些值大量缓存在 `CMakeCache.txt`，直接切换会得到难以解释的混合配置；应新建 build 目录或在确认目标后删除那个特定 build 目录重配。

## 第一轮建议的最小配置

为学习源码和运行普通 netlist，先构建：**串行 + Release + 关闭插件 + 关闭 FFTW + 关闭完整回归**。

配置阶段的形状如下（这里是下一轮执行时的模板，不是本轮已执行命令）：

```sh
cmake -S vendor/Xyce-7.10.0 -B build/xyce-7.10-serial-release \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PWD/out/xyce-7.10-serial-release" \
  -DTrilinos_ROOT="$HOME/.local/xyce-deps/install" \
  -DXyce_PARALLEL_MPI=OFF \
  -DXyce_PLUGIN_SUPPORT=OFF \
  -DXyce_USE_FFT=OFF \
  -DBUILD_TESTING=OFF
```

随后才是：

```sh
cmake --build build/xyce-7.10-serial-release --parallel <安全的并行度>
cmake --install build/xyce-7.10-serial-release
```

这里的 `$HOME` 只是文档中的用户目录占位符；实际执行时应写成确认过的依赖前缀。若 flex/bison 不在默认搜索路径，还需要显式传入 `FLEX_EXECUTABLE`、`FLEX_INCLUDE_DIR` 和 `BISON_EXECUTABLE`。

## 功能开关应按需求增加

| 需求 | Xyce 配置 | 额外前提 |
| --- | --- | --- |
| 分布式内存并行 | `Xyce_PARALLEL_MPI=ON`，并用 MPI C/C++ 编译器配置 | MPI 版 Trilinos；同一 MPI 实现 |
| Harmonic Balance 等 FFT 分析 | `Xyce_USE_FFT=ON` | FFTW 3.x 或 Intel MKL |
| Verilog-A / 用户插件 | `Xyce_PLUGIN_SUPPORT=ON` | 先安装 ADMS；项目会强制共享库 |
| 单元测试 | `BUILD_TESTING=ON`，按需启用 `Xyce_GTEST_UNIT_TESTS` | GoogleTest（仅相关测试） |
| 完整回归 | `Xyce_REGRESSION=ON` | 另行取得 `Xyce_Regression`；Perl、Bash，部分测试还需 Python/Numpy/Scipy |

不应为了“功能最全”在首个构建中一次性打开所有选项。先让最小串行构建稳定通过，再按一个能力点一个 build tree 增量扩展，才能把配置错误定位在正确层级。

## 当前本机状态（只读检查，2026-07-22）

已发现：

- CMake 3.26.5、GCC/G++ 8.5.0、make、flex、bison 可用；
- `build/` 已是一个针对本地 Xyce 7.10 源码的 CMake 串行 `Release` 配置；
- 它的 `Trilinos_ROOT` 指向 `/home/eda/.local/xyce-deps/install`，并显式使用该用户目录下的 flex/bison；
- 已关闭 `Xyce_PARALLEL_MPI`、`Xyce_USE_FFT`、`Xyce_PLUGIN_SUPPORT`、`BUILD_TESTING` 和 `Xyce_REGRESSION`；
- build 树内存在 `src/libxyce.a`，但未发现 `build/src/Xyce`，也没有安装后的可执行文件；因此不能把当前状态视作已完成安装；
- FFTW 在该 CMake cache 中未找到，这与 `Xyce_USE_FFT=OFF` 相符；未检查或修改系统级包。

## 首次实际编译时的验收顺序

1. 配置结束：确认 CMake 找到了正确的 Trilinos、flex、bison，且串行/MPI 选择正确。
2. 编译结束：确认目标 `Xyce` 链接完成，而不只是 `libxyce.a` 已生成。
3. 安装结束：确认 `<prefix>/bin/Xyce` 存在。
4. 冒烟运行：执行 `<prefix>/bin/Xyce -h`，再运行一个最小电阻电路。
5. 按目标补测：需要可靠性结论时，另行接入 `Xyce_Regression` 跑回归测试。

## 常见误区

- **只看 configure 成功。** 配置成功只说明依赖探测通过，不说明所有源文件和最终链接都已完成。
- **串行 Trilinos 配 MPI Xyce。** 这不是运行时选项，而是 ABI 和通信层的构建属性。
- **复用同一 build 目录切换编译器或功能。** CMake cache 会保留旧探测结果。
- **把安装前缀设为系统目录。** 对学习项目更适合使用仓库内 `out/`，避免权限和清理风险。
- **看到旧的 `configure` 文件就使用 Autotools。** 对 7.10 应优先使用 CMake；Autotools 已被上游标为弃用。

## 本篇核心结论

Xyce 的真正构建单位不是单独的源码目录，而是下面这个完整组合：

```text
Xyce 源码版本
+ SuiteSparse / Trilinos 的精确版本和启用包
+ 编译器与 MPI 实现
+ CMake 功能开关
= 一套可运行、可复现的 Xyce 安装
```

下一步应先把当前本机依赖前缀和现有 build cache 做成一份“构建前检查清单”，再决定是恢复这套串行构建，还是从一个命名清晰的新 build 目录重新配置。
