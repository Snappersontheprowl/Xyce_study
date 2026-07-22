# Xyce 7.10 最小分层构建执行记录

本文件记录实际执行过程。`02-layered-minimal-build-plan.md` 负责描述计划，本文件负责保存每一阶段的证据、判断和下一步动作。

当前协作模式：用户执行编译构建命令，Codex 负责指导、监督、检查日志和维护文档。

## 2026-07-22：阶段 0 工具链冻结

### 用户已执行

```bash
cd /home/eda/my_lab/projects/study/xyce_study

xyce_cc="/opt/rh/gcc-toolset-15/root/usr/bin/gcc"
xyce_cxx="/opt/rh/gcc-toolset-15/root/usr/bin/g++"

cmake --version
make --version | head -n 1
"$xyce_cc" --version | head -n 1
"$xyce_cxx" --version | head -n 1
/home/eda/.local/xyce-tools/bin/flex --version
/home/eda/.local/xyce-tools/bin/bison --version
```

### 观察结果

| 工具 | 结果 | 判断 |
|---|---:|---|
| CMake | 3.26.5 | 满足 Xyce 顶层 CMake 3.22+ 要求 |
| GNU Make | 4.2.1 | 可用于后续构建 |
| GCC | 15.2.1 | 满足 Xyce `INSTALL.md` 的 GCC 9+ 示例基线 |
| G++ | 15.2.1 | 与 GCC 来自同一 `gcc-toolset-15` |
| flex | 2.6.4 | 满足 Xyce 要求 |
| bison | 3.8.2 | 满足 Xyce 要求 |

### 阶段判断

阶段 0 通过。

本轮正式工具链固定为：

```bash
xyce_cc="/opt/rh/gcc-toolset-15/root/usr/bin/gcc"
xyce_cxx="/opt/rh/gcc-toolset-15/root/usr/bin/g++"
```

后续 SuiteSparse、Trilinos、Xyce 的 CMake 配置都必须使用这两个绝对路径。不得中途切回 `/usr/bin/gcc` 或 `/usr/bin/g++`。

### 下一步

阶段 1 执行只读审计：确认旧依赖前缀中的 Trilinos 14.4 由 GCC 8.5 构建，并记录其不作为正式复用目标的证据。

## 2026-07-22：阶段 1 旧依赖前缀审计

### 用户已执行

```bash
xyce_existing_deps="/home/eda/.local/xyce-deps/install"

test -f "$xyce_existing_deps/lib/cmake/Trilinos/TrilinosConfig.cmake" && echo "TrilinosConfig exists"
test -f "$xyce_existing_deps/include/TrilinosConfig.cmake" && echo "include TrilinosConfig exists"

rg -n 'Trilinos_VERSION|Trilinos_PACKAGE_LIST|Trilinos_(C|CXX|Fortran)*COMPILER|Trilinos*(C|CXX|Fortran)_COMPILER_ID|Trilinos_MPI_EXEC' \
  "$xyce_existing_deps/lib/cmake/Trilinos/TrilinosConfig.cmake"

find "$xyce_existing_deps" -maxdepth 3 -type f \( -name 'libamd.*' -o -name 'libamd.so*' \) | sort
```

### 观察结果

旧依赖前缀存在 Trilinos 配置文件：

```text
/home/eda/.local/xyce-deps/install/lib/cmake/Trilinos/TrilinosConfig.cmake
/home/eda/.local/xyce-deps/install/include/TrilinosConfig.cmake
```

关键配置摘录：

```cmake
set(Trilinos_CXX_COMPILER "/usr/bin/g++")
set(Trilinos_C_COMPILER "/usr/bin/gcc")
set(Trilinos_Fortran_COMPILER "")
set(Trilinos_VERSION "14.4")
set(Trilinos_MPI_EXEC "")
set(Trilinos_CXX_COMPILER_ID "GNU")
set(Trilinos_C_COMPILER_ID "GNU")
set(Trilinos_Fortran_COMPILER_ID "")
set(Trilinos_PACKAGE_LIST "TrilinosCouplings;ROL;Stokhos;NOX;Amesos2;Belos;Ifpack;Amesos;AztecOO;TrilinosSS;Tpetra;TpetraCore;EpetraExt;Triutils;Epetra;Sacado;KokkosKernels;Teuchos;TeuchosKokkosComm;TeuchosKokkosCompat;TeuchosRemainder;TeuchosNumerics;TeuchosComm;TeuchosParameterList;TeuchosParser;TeuchosCore;Kokkos")
```

旧前缀中存在 AMD 库：

```text
/home/eda/.local/xyce-deps/install/lib64/libamd.a
/home/eda/.local/xyce-deps/install/lib64/libamd.so.3.3.3
```

### 阶段判断

阶段 1 通过。

旧 Trilinos 的版本和包列表对 Xyce 有参考价值，但其 C/C++ 编译器为 `/usr/bin/gcc` 与 `/usr/bin/g++`，即系统默认 GCC 8.5 工具链。这与阶段 0 固定的 GCC Toolset 15 不一致。

正式最小构建不复用该前缀。后续从阶段 2 开始，在新的依赖前缀中用 GCC Toolset 15 重建 SuiteSparse 和 Trilinos。

### 当前源码状态

只读检查未在 `artifacts/source/` 下发现 SuiteSparse 或 Trilinos 源码目录/归档。进入阶段 2 前，需要先获取 SuiteSparse 7.8.3 或更新版本的源码，并记录来源。

## 2026-07-22：阶段 2A SuiteSparse 源码获取

### 用户已执行

```bash
cd /home/eda/my_lab/projects/study/xyce_study
mkdir -p artifacts/source
cd artifacts/source

curl -L \
  -o SuiteSparse-7.8.3.tar.gz \
  https://github.com/DrTimothyAldenDavis/SuiteSparse/archive/refs/tags/v7.8.3.tar.gz

sha256sum SuiteSparse-7.8.3.tar.gz
tar -xf SuiteSparse-7.8.3.tar.gz
test -d SuiteSparse-7.8.3 && echo "SuiteSparse source ready"

find SuiteSparse-7.8.3 -maxdepth 2 -type f \( -name 'CMakeLists.txt' -o -name '*version*' -o -name '*Version*' \) | sort | head -n 40
```

### 观察结果

源码归档下载完成：

```text
SuiteSparse-7.8.3.tar.gz
```

校验值：

```text
ce39b28d4038a09c14f21e02c664401be73c0cb96a9198418d6a98a7db73a259  SuiteSparse-7.8.3.tar.gz
```

解压目录存在：

```text
SuiteSparse source ready
```

源码树中存在顶层和关键子项目的 CMake 文件：

```text
SuiteSparse-7.8.3/CMakeLists.txt
SuiteSparse-7.8.3/AMD/CMakeLists.txt
SuiteSparse-7.8.3/SuiteSparse_config/CMakeLists.txt
```

### Codex 只读检查

SuiteSparse 7.8.3 顶层 `CMakeLists.txt` 定义了：

```cmake
set ( SUITESPARSE_ENABLE_PROJECTS "all" CACHE STRING ... )
```

其中合法项目列表包含 `suitesparse_config` 和 `amd`。因此本计划中的最小项目选择是合法的：

```bash
-DSUITESPARSE_ENABLE_PROJECTS="suitesparse_config;amd"
```

版本信息：

```text
SuiteSparse_config: 7.8.3
AMD: 3.3.3
```

SuiteSparse policy 文件显示：

```cmake
option ( SUITESPARSE_DEMOS ... OFF )
option ( BUILD_SHARED_LIBS ... ON )
option ( BUILD_STATIC_LIBS ... ON )
option ( SUITESPARSE_USE_FORTRAN ... ON )
```

为保持最小构建，后续配置将显式关闭 Fortran 与 OpenMP，并显式保留 static/shared 产物。

### 阶段判断

阶段 2A 通过。可以进入 SuiteSparse CMake 配置，但先只配置并审查 `CMakeCache.txt`，不要直接编译。
