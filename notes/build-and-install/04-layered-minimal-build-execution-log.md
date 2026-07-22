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

## 2026-07-22：阶段 2B SuiteSparse 首次配置失败

### 用户反馈的失败

SuiteSparse CMake 配置在 `SuiteSparse_config` 的 BLAS 探测处停止：

```text
-- Could NOT find BLAS (missing: BLAS_LIBRARIES)
-- Looking for any 32-bit BLAS
-- Looking for sgemm_
-- Looking for sgemm_ - not found
CMake Error at .../FindBLAS.cmake:
  Could NOT find BLAS (missing: BLAS_LIBRARIES)
```

### Codex 只读检查

失败后的 `CMakeCache.txt` 中，阶段 0 固定的工具链和阶段 2 的 SuiteSparse 开关是正确的：

```cmake
CMAKE_C_COMPILER=/opt/rh/gcc-toolset-15/root/usr/bin/gcc
CMAKE_CXX_COMPILER=/opt/rh/gcc-toolset-15/root/usr/bin/g++
CMAKE_BUILD_TYPE=Release
CMAKE_INSTALL_PREFIX=/home/eda/my_lab/projects/study/xyce_study/out/deps/xyce-7.10-serial-release
SUITESPARSE_ENABLE_PROJECTS=suitesparse_config;amd
SUITESPARSE_USE_FORTRAN=OFF
SUITESPARSE_USE_OPENMP=OFF
SUITESPARSE_DEMOS=OFF
BUILD_SHARED_LIBS=ON
BUILD_STATIC_LIBS=ON
```

因此本次失败不是工具链混用，而是缺少可被 CMake 自动发现的 BLAS。

本机未发现标准系统 BLAS/OpenBLAS/LAPACK 开发包；`dnf list available` 当前也未列出可安装候选。只读搜索发现 Cadence IC231 自带 BLAS/LAPACK：

```text
/opt/cadence/IC231/tools.lnx86/lapack/lib/64bit/libblas.so
/opt/cadence/IC231/tools.lnx86/lapack/lib/64bit/liblapack.so
```

这两个库为 x86-64 ELF 动态库。符号检查显示：

```text
libblas.so:   dgemm_, sgemm_
liblapack.so: dgeev_, dgesv_
```

`ldd` 显示 Cadence BLAS/LAPACK 会依赖同一 Cadence 安装树中的 `libgfortran.so.5`、`libquadmath.so.0` 和 `libgcc_s.so.1`。

### 阶段判断

阶段 2B 未通过，需要带显式 BLAS/LAPACK 路径重新配置 SuiteSparse。

当时的临时路线是使用 Cadence IC231 自带 BLAS/LAPACK 作为本机可用数值库。后续复核认为更干净路线应优先使用系统 BLAS/LAPACK 或项目专用 OpenBLAS；但由于当前缺少可用的 GCC Toolset 15 `gfortran`，本轮最小构建接受 Cadence 路线作为显式 fallback。

## 2026-07-22：阶段 2B SuiteSparse 重新配置通过

### 用户反馈的结果

带显式 BLAS/LAPACK 路径重新配置后，SuiteSparse CMake 完成：

```text
-- Configuring done
-- Generating done
-- Build files have been written to:
   /home/eda/my_lab/projects/study/xyce_study/build/deps/xyce-7.10-serial-release/suitesparse
```

CMake 同时报告：

```text
Manually-specified variables were not used by the project:
  BLAS_LIBRARIES
  LAPACK_LIBRARIES
```

### Cache 检查

关键 cache 项正确：

```cmake
BLAS_LIBRARIES=/opt/cadence/IC231/tools.lnx86/lapack/lib/64bit/libblas.so
LAPACK_LIBRARIES=/opt/cadence/IC231/tools.lnx86/lapack/lib/64bit/liblapack.so
BUILD_SHARED_LIBS=ON
BUILD_STATIC_LIBS=ON
BUILD_TESTING=OFF
CMAKE_BUILD_TYPE=Release
CMAKE_CXX_COMPILER=/opt/rh/gcc-toolset-15/root/usr/bin/g++
CMAKE_C_COMPILER=/opt/rh/gcc-toolset-15/root/usr/bin/gcc
CMAKE_INSTALL_PREFIX=/home/eda/my_lab/projects/study/xyce_study/out/deps/xyce-7.10-serial-release
SUITESPARSE_DEMOS=OFF
SUITESPARSE_ENABLE_PROJECTS=suitesparse_config;amd
SUITESPARSE_USE_FORTRAN=OFF
SUITESPARSE_USE_OPENMP=OFF
```

生成目录包含预期子项目：

```text
build/deps/xyce-7.10-serial-release/suitesparse/AMD
build/deps/xyce-7.10-serial-release/suitesparse/SuiteSparse_config
```

### Codex 只读检查

生成的 link 文件显示当前最小子集实际不直接链接 BLAS/LAPACK：

```text
libsuitesparseconfig.so.7.8.3 links with -lm
libamd.so.3.3.3 links with libsuitesparseconfig.so.7.8.3 and -lm
libamd.a is archived from AMD object files
```

因此 `BLAS_LIBRARIES`、`LAPACK_LIBRARIES` 的 unused warning 对当前 SuiteSparse 最小子集可接受。这两个 cache 变量未参与该子集链接；后续 Trilinos 将显式使用同一组 Cadence IC231 BLAS/LAPACK fallback，见本文件末尾的策略复核记录。

### 阶段判断

阶段 2B 通过。可以进入阶段 2C：编译并安装 SuiteSparse。

## 2026-07-22：数值库策略复核——本轮接受 Cadence fallback

### 触发原因

用户提出应否以更干净的方式提供 BLAS/LAPACK。复核发现，当前 SuiteSparse 的最小 `suitesparse_config + AMD` 子集并不链接先前传入的 Cadence BLAS/LAPACK；该路径仅用于使其顶层配置的 BLAS 探测通过。

同时，Cadence IC231 的 `libblas.so`、`liblapack.so` 依赖 Cadence 安装树中的 `libgfortran.so.5`、`libquadmath.so.0`、`libgcc_s.so.1`。这会让最终 Trilinos/Xyce 的数值库运行时依赖一个项目外的 EDA 软件安装，降低可移植性与可追溯性。

### 决策

更干净的优先级仍是：

1. 系统包提供的 OpenBLAS/LAPACK 开发库；
2. 项目本地前缀中用同一 GCC Toolset 构建的 OpenBLAS/LAPACK；
3. Cadence IC231 自带 BLAS/LAPACK fallback。

用户随后检查：

```bash
test -x /opt/rh/gcc-toolset-15/root/usr/bin/gfortran && \
  /opt/rh/gcc-toolset-15/root/usr/bin/gfortran --version | head -n 1

dnf list available 'gcc-toolset-15*gfortran*' 'gcc-toolset-15*fortran*'
```

第一条没有输出，说明当前没有 GCC Toolset 15 `gfortran`。第二条被外部 `nodesource-nodejs` 仓库元数据下载错误阻断：

```text
Error: Failed to download metadata for repo 'nodesource-nodejs'
```

因此本轮不再强制新增项目专用 OpenBLAS 层。正式最小构建接受 Cadence IC231 自带 BLAS/LAPACK 作为显式 fallback，并在后续 Trilinos 配置中统一使用：

```text
/opt/cadence/IC231/tools.lnx86/lapack/lib/64bit/libblas.so
/opt/cadence/IC231/tools.lnx86/lapack/lib/64bit/liblapack.so
```

Trilinos 仍保持 `Trilinos_ENABLE_Fortran=OFF`；使用 Cadence BLAS/LAPACK 不表示启用 Trilinos 的 Fortran 接口，也不会引入 MPI。

### 对现有工作物的影响

- 已成功配置的 SuiteSparse build tree 不需要删除或重配：Cadence 的 `BLAS_LIBRARIES`、`LAPACK_LIBRARIES` 在该最小子集中未被消费。
- SuiteSparse 可按原计划先完成 build/install。
- 在配置 Trilinos 前，需要复核并记录 Cadence BLAS/LAPACK 的符号和运行时依赖。

详细操作已更新至 [02-layered-minimal-build-plan.md](./02-layered-minimal-build-plan.md) 的“阶段 2.5”。

## 2026-07-22：阶段 2C SuiteSparse 编译与安装通过

### 用户反馈的结果

SuiteSparse build 完成，最终目标均构建成功：

```text
[ 98%] Linking C static library libamd.a
[100%] Linking C shared library libamd.so
[100%] Built target AMD_static
[100%] Built target AMD
```

安装命令：

```bash
cmake --install "$xyce_suitesparse_build"
```

安装前缀：

```text
/home/eda/my_lab/projects/study/xyce_study/out/deps/xyce-7.10-serial-release
```

### 安装产物

已安装 SuiteSparse_config：

```text
lib64/libsuitesparseconfig.so.7.8.3
lib64/libsuitesparseconfig.so.7
lib64/libsuitesparseconfig.so
lib64/libsuitesparseconfig.a
include/suitesparse/SuiteSparse_config.h
lib64/cmake/SuiteSparse_config/SuiteSparse_configConfig.cmake
lib64/cmake/SuiteSparse_config/SuiteSparse_configConfigVersion.cmake
lib64/pkgconfig/SuiteSparse_config.pc
```

已安装 AMD：

```text
lib64/libamd.so.3.3.3
lib64/libamd.so.3
lib64/libamd.so
lib64/libamd.a
include/suitesparse/amd.h
lib64/cmake/AMD/AMDConfig.cmake
lib64/cmake/AMD/AMDConfigVersion.cmake
lib64/pkgconfig/AMD.pc
```

验收检查通过：

```text
libamd.a ready
AMDConfig ready
SuiteSparse_configConfig ready
```

### Codex 只读复核

复核确认以下关键文件存在：

```text
out/deps/xyce-7.10-serial-release/include/suitesparse/amd.h
out/deps/xyce-7.10-serial-release/include/suitesparse/SuiteSparse_config.h
out/deps/xyce-7.10-serial-release/lib64/cmake/AMD/AMDConfig.cmake
out/deps/xyce-7.10-serial-release/lib64/cmake/SuiteSparse_config/SuiteSparse_configConfig.cmake
out/deps/xyce-7.10-serial-release/lib64/libamd.a
out/deps/xyce-7.10-serial-release/lib64/libamd.so.3.3.3
out/deps/xyce-7.10-serial-release/lib64/libsuitesparseconfig.a
out/deps/xyce-7.10-serial-release/lib64/libsuitesparseconfig.so.7.8.3
```

SuiteSparse build tree 中已生成：

```text
build/deps/xyce-7.10-serial-release/suitesparse/install_manifest.txt
```

### 阶段判断

阶段 2C 通过。SuiteSparse 最小子集 `suitesparse_config + AMD` 已经安装到目标依赖前缀。

下一阶段是 2.5：在进入 Trilinos 前，复核 Cadence IC231 BLAS/LAPACK fallback 的路径、符号和运行时依赖。

## 2026-07-22：阶段 2.5 Cadence BLAS/LAPACK fallback 复核通过

### 用户已执行

```bash
xyce_blas_lapack_libdir="/opt/cadence/IC231/tools.lnx86/lapack/lib/64bit"
xyce_blas="$xyce_blas_lapack_libdir/libblas.so"
xyce_lapack="$xyce_blas_lapack_libdir/liblapack.so"

test -f "$xyce_blas" && echo "BLAS exists: $xyce_blas"
test -f "$xyce_lapack" && echo "LAPACK exists: $xyce_lapack"

nm -D "$xyce_blas" | rg ' (sgemm_|dgemm_)$'
nm -D "$xyce_lapack" | rg ' (dgesv_|dgeev_)$'

ldd "$xyce_blas"
ldd "$xyce_lapack"
```

### 观察结果

库文件存在：

```text
BLAS exists: /opt/cadence/IC231/tools.lnx86/lapack/lib/64bit/libblas.so
LAPACK exists: /opt/cadence/IC231/tools.lnx86/lapack/lib/64bit/liblapack.so
```

BLAS 符号存在：

```text
0000000000055e90 T dgemm_
000000000007ef60 T sgemm_
```

LAPACK 符号存在：

```text
00000000001d8f40 T dgeev_
00000000001f4350 T dgesv_
```

`libblas.so` 运行时依赖：

```text
libgfortran.so.5 => /opt/cadence/IC231/tools.lnx86/lapack/lib/64bit/../../../lib/64bit/libgfortran.so.5
libm.so.6 => /lib64/libm.so.6
libc.so.6 => /lib64/libc.so.6
libquadmath.so.0 => /opt/cadence/IC231/tools.lnx86/lapack/lib/64bit/../../../lib/64bit/libquadmath.so.0
libgcc_s.so.1 => /opt/cadence/IC231/tools.lnx86/lapack/lib/64bit/../../../lib/64bit/libgcc_s.so.1
```

`liblapack.so` 运行时依赖：

```text
libblas.so => /opt/cadence/IC231/tools.lnx86/lapack/lib/64bit/../../../lapack/lib/64bit/libblas.so
libgfortran.so.5 => /opt/cadence/IC231/tools.lnx86/lapack/lib/64bit/../../../lib/64bit/libgfortran.so.5
libm.so.6 => /lib64/libm.so.6
libc.so.6 => /lib64/libc.so.6
libquadmath.so.0 => /opt/cadence/IC231/tools.lnx86/lapack/lib/64bit/../../../lib/64bit/libquadmath.so.0
libgcc_s.so.1 => /opt/cadence/IC231/tools.lnx86/lapack/lib/64bit/../../../lib/64bit/libgcc_s.so.1
```

`ldd` 对两个 `.so` 都提示没有 execution permission。该 warning 不影响本次判断；共享库不需要执行位即可被动态链接器加载。

### 阶段判断

阶段 2.5 通过。

本轮正式接受 Cadence IC231 BLAS/LAPACK fallback，并记录其已知代价：运行时依赖 Cadence 安装树中的 Fortran runtime。后续 Trilinos 配置必须显式使用：

```text
BLAS_LIBRARY_DIRS=/opt/cadence/IC231/tools.lnx86/lapack/lib/64bit
LAPACK_LIBRARY_DIRS=/opt/cadence/IC231/tools.lnx86/lapack/lib/64bit
BLAS_LIBRARY_NAMES=blas
LAPACK_LIBRARY_NAMES=lapack
```

下一阶段是阶段 3：准备并配置 Trilinos 14.4。
