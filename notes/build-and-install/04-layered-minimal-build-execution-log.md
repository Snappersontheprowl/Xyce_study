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

## 2026-07-22：阶段 3A Trilinos 14.4 源码获取

### 用户已执行

```bash
cd /home/eda/my_lab/projects/study/xyce_study/artifacts/source

curl -L \
  -o Trilinos-14.4.zip \
  https://github.com/trilinos/Trilinos/archive/refs/heads/trilinos-release-14-4-branch.zip

wget --no-check-certificate \
  https://github.com/trilinos/Trilinos/archive/refs/heads/trilinos-release-14-4-branch.zip \
  -O Trilinos-14.4.zip

sha256sum Trilinos-14.4.zip
unzip -q Trilinos-14.4.zip

if test -d Trilinos-trilinos-release-14-4-branch; then
  mv Trilinos-trilinos-release-14-4-branch Trilinos-14.4
fi

test -d Trilinos-14.4 && echo "Trilinos source ready"

find Trilinos-14.4 -maxdepth 2 -type f \( \
  -name 'CMakeLists.txt' -o \
  -name 'Version.cmake' -o \
  -name '*Version*' -o \
  -name 'Trilinos_version.h.in' \
\) | sort | head -n 60
```

### 观察结果

`curl` 首次下载失败：

```text
curl: (35) OpenSSL SSL_connect: SSL_ERROR_SYSCALL in connection to github.com:443
```

随后 `wget --no-check-certificate` 成功下载：

```text
Trilinos-14.4.zip saved [231528416]
```

校验值：

```text
ab3d0d1cc73be4bc3c92c6a991b66ada89fcd6a59663c47c079592b497c3d1f3  Trilinos-14.4.zip
```

解压目录存在：

```text
Trilinos source ready
```

关键文件存在：

```text
Trilinos-14.4/CMakeLists.txt
Trilinos-14.4/Version.cmake
```

### Codex 只读复核

`Version.cmake` 中的版本信息：

```cmake
SET(Trilinos_VERSION 14.4)
SET(Trilinos_MAJOR_VERSION 14)
SET(Trilinos_MAJOR_MINOR_VERSION 140400)
SET(Trilinos_VERSION_STRING "14.4")
SET(Trilinos_REPOSITORY_BRANCH "trilinos-release-14-4-branch" CACHE INTERNAL "")
```

源码树中存在关键目录：

```text
Trilinos-14.4/cmake
Trilinos-14.4/commonTools
Trilinos-14.4/packages
```

Xyce 所需关键 package 目录存在：

```text
amesos
amesos2
aztecoo
belos
epetraext
ifpack
nox
rol
sacado
stokhos
teuchos
tpetra
```

### 阶段判断

阶段 3A 通过。可以进入阶段 3B：配置 Trilinos，但先只配置并审查 `CMakeCache.txt`，不要直接编译。

## 2026-07-22：阶段 3B Trilinos 配置通过

### 用户反馈的结果

Trilinos CMake 配置完成：

```text
Finished configuring Trilinos!
-- Configuring done (10.8s)
-- Generating done (0.5s)
-- Build files have been written to:
   /home/eda/my_lab/projects/study/xyce_study/build/deps/xyce-7.10-serial-release/trilinos
```

### Cache 检查

关键工具链与前缀：

```cmake
CMAKE_BUILD_TYPE=Release
CMAKE_CXX_COMPILER=/opt/rh/gcc-toolset-15/root/usr/bin/g++
CMAKE_C_COMPILER=/opt/rh/gcc-toolset-15/root/usr/bin/gcc
CMAKE_INSTALL_PREFIX=/home/eda/my_lab/projects/study/xyce_study/out/deps/xyce-7.10-serial-release
Trilinos_ENABLE_Fortran=OFF
```

SuiteSparse/AMD：

```cmake
AMD_INCLUDE_DIRS=/home/eda/my_lab/projects/study/xyce_study/out/deps/xyce-7.10-serial-release/include/suitesparse
AMD_LIBRARY_DIRS=/home/eda/my_lab/projects/study/xyce_study/out/deps/xyce-7.10-serial-release/lib64
TPL_ENABLE_AMD=ON
```

Cadence BLAS/LAPACK fallback：

```cmake
BLAS_LIBRARY_DIRS=/opt/cadence/IC231/tools.lnx86/lapack/lib/64bit
BLAS_LIBRARY_NAMES=blas
LAPACK_LIBRARY_DIRS=/opt/cadence/IC231/tools.lnx86/lapack/lib/64bit
LAPACK_LIBRARY_NAMES=lapack
TPL_ENABLE_BLAS=ON
TPL_ENABLE_LAPACK=ON
```

Serial mode:

```cmake
TPL_ENABLE_MPI=OFF
```

Xyce 需要的关键 Trilinos packages：

```cmake
Trilinos_ENABLE_Amesos=ON
Trilinos_ENABLE_Amesos2=ON
Trilinos_ENABLE_AztecOO=ON
Trilinos_ENABLE_Belos=ON
Trilinos_ENABLE_COMPLEX_DOUBLE=ON
Trilinos_ENABLE_EpetraExt=ON
Trilinos_ENABLE_Ifpack=ON
Trilinos_ENABLE_NOX=ON
Trilinos_ENABLE_ROL=ON
Trilinos_ENABLE_Sacado=ON
Trilinos_ENABLE_Stokhos=ON
Trilinos_ENABLE_Teuchos=ON
Trilinos_ENABLE_TrilinosCouplings=ON
```

### Codex 只读复核

进一步确认 TPL 最终解析：

```cmake
TPL_AMD_INCLUDE_DIRS=/home/eda/my_lab/projects/study/xyce_study/out/deps/xyce-7.10-serial-release/include/suitesparse
TPL_AMD_LIBRARIES=/home/eda/my_lab/projects/study/xyce_study/out/deps/xyce-7.10-serial-release/lib64/libamd.so
TPL_BLAS_LIBRARIES=/opt/cadence/IC231/tools.lnx86/lapack/lib/64bit/libblas.so
TPL_LAPACK_LIBRARIES=/opt/cadence/IC231/tools.lnx86/lapack/lib/64bit/liblapack.so
TPL_AMD_NOT_FOUND=FALSE
TPL_BLAS_NOT_FOUND=FALSE
TPL_LAPACK_NOT_FOUND=FALSE
```

LAPACK 探测测试：

```cmake
LAPACK_SLAPY2_WORKS=1
LAPACK_SLAPY2_WORKS_COMPILED=TRUE
LAPACK_SLAPY2_WORKS_EXITCODE=0
```

CMake 生成了顶层 Makefile：

```text
build/deps/xyce-7.10-serial-release/trilinos/Makefile
```

日志位置：

```text
build/deps/xyce-7.10-serial-release/trilinos/CMakeFiles/CMakeConfigureLog.yaml
```

未发现旧式 `CMakeError.log` / `CMakeOutput.log`，这不构成失败。

### 阶段判断

阶段 3B 通过。可以进入阶段 3C：编译并安装 Trilinos。由于 Trilinos 较重，首轮仍使用 `--parallel 2`，失败时保留 build tree 并回传第一处错误。

## 2026-07-22：阶段 3C Trilinos 首次编译失败

### 用户反馈的结果

执行 Trilinos 编译时，进度到约 19% 后失败：

```text
[ 19%] Building CXX object packages/kokkos-kernels/...
```

第一处真实错误位于 KokkosKernels：

```text
artifacts/source/Trilinos-14.4/packages/kokkos-kernels/sparse/src/KokkosSparse_spadd_handle.hpp:75:44:
error: ‘class KokkosSparse::SPADDHandle<...>’ has no member named ‘sort_option’; did you mean ‘set_sort_option’? [-Wtemplate-body]

artifacts/source/Trilinos-14.4/packages/kokkos-kernels/sparse/src/KokkosSparse_spadd_handle.hpp:77:40:
error: ‘class KokkosSparse::SPADDHandle<...>’ has no member named ‘sort_option’; did you mean ‘set_sort_option’? [-Wtemplate-body]
```

最终失败目标：

```text
packages/kokkos-kernels/CMakeFiles/kokkoskernels.dir/all
```

### Codex 只读复核

本地源码文件：

```text
artifacts/source/Trilinos-14.4/packages/kokkos-kernels/sparse/src/KokkosSparse_spadd_handle.hpp
```

在该类中可以看到：

```cpp
void set_sort_option(int option) { this->sort_option = option; }

int get_sort_option() { return this->sort_option; }
```

但类的 private 成员区只有：

```cpp
bool input_sorted;
size_type result_nnz_size;
bool called_symbolic;
bool called_numeric;
nnz_lno_view_t a_pos;
nnz_lno_view_t b_pos;
```

未定义 `sort_option` 成员。

该问题与上游已知问题一致：

- KokkosKernels issue: `error: no member named 'sort_option' in 'SPADDHandle'`
- Trilinos issue: `Build fails with clang-19: no member named 'sort_option'...`

虽然上游 issue 的触发编译器示例包含 Clang 19，但本次 GCC 15.2.1 也会在模板体检查阶段暴露同一缺陷。

### 判断

阶段 3C 未通过。

这不是：

- BLAS/LAPACK 配置问题；
- SuiteSparse/AMD 安装问题；
- MPI/Fortran 配置问题；
- 链接阶段问题。

这是 Trilinos 14.4 分支中内置 KokkosKernels 代码的源码级缺陷：成员函数访问了不存在的 `sort_option` 成员。

### 建议处置

首选采用最小源码补丁，而不是更换整个工具链或重配复杂 package 组合。

建议补丁位置：

```text
artifacts/source/Trilinos-14.4/packages/kokkos-kernels/sparse/src/KokkosSparse_spadd_handle.hpp
```

建议补丁内容：

```cpp
private:
  bool input_sorted;

  size_type result_nnz_size;

  bool called_symbolic;
  bool called_numeric;
  int sort_option;
```

并在构造函数初始化列表中补充：

```cpp
SPADDHandle(bool input_is_sorted)
    : input_sorted(input_is_sorted),
      result_nnz_size(0),
      called_symbolic(false),
      called_numeric(false),
      sort_option(0) {}
```

### 下一步

先暂停 Trilinos 编译。待确认是否允许对第三方源码树应用该最小补丁。

若确认应用补丁，补丁后无需重新配置 CMake，直接重新执行：

```bash
cmake --build "$xyce_trilinos_build" --parallel 2
```

## 2026-07-22：阶段 3C Trilinos KokkosKernels 最小源码补丁已应用

### 用户确认

用户确认：

```text
好的，请你修补源码
```

### 实际修改

已修补当前 Trilinos 源码树：

```text
artifacts/source/Trilinos-14.4/packages/kokkos-kernels/sparse/src/KokkosSparse_spadd_handle.hpp
```

修改内容：

```cpp
bool called_symbolic;
bool called_numeric;
int sort_option;
```

构造函数初始化列表同步补充：

```cpp
SPADDHandle(bool input_is_sorted)
    : input_sorted(input_is_sorted),
      result_nnz_size(0),
      called_symbolic(false),
      called_numeric(false),
      sort_option(0) {}
```

### 可复现补丁

由于 `artifacts/source/*` 被 `.gitignore` 忽略，当前源码树中的改动不会自然进入 git 跟踪。

为保证后续可复现，已保存补丁文件：

```text
notes/build-and-install/patches/trilinos-14.4-kokkoskernels-spadd-sort-option.patch
```

如果将来重新解压 Trilinos 源码，可在源码根目录应用：

```bash
cd /home/eda/my_lab/projects/study/xyce_study/artifacts/source/Trilinos-14.4
patch -p1 < /home/eda/my_lab/projects/study/xyce_study/notes/build-and-install/patches/trilinos-14.4-kokkoskernels-spadd-sort-option.patch
```

### 下一步

无需重新配置 Trilinos CMake。请继续执行：

```bash
cmake --build "$xyce_trilinos_build" --parallel 2
```

若继续失败，仍然只回传第一处真实错误即可。

## 2026-07-22：阶段 3C Trilinos 第二次编译失败，推进到 AztecOO

### 用户反馈的结果

应用 KokkosKernels `sort_option` 最小补丁后，Trilinos 编译已越过此前 19% 的 `kokkoskernels` 失败点，继续推进到约 41%。

新的第一处真实错误位于 AztecOO：

```text
artifacts/source/Trilinos-14.4/packages/aztecoo/src/az_aztec.h:611:42:
error: implicit declaration of function ‘az_fnroot_c’ [-Wimplicit-function-declaration]

artifacts/source/Trilinos-14.4/packages/aztecoo/src/az_aztec.h:613:42:
error: implicit declaration of function ‘az_rcm_c’ [-Wimplicit-function-declaration]
```

触发编译单元：

```text
packages/aztecoo/src/CMakeFiles/aztecoo.dir/az_domain_decomp.c.o
```

最终失败目标：

```text
packages/aztecoo/src/CMakeFiles/aztecoo.dir/all
```

### Codex 只读复核

相关宏位于：

```text
artifacts/source/Trilinos-14.4/packages/aztecoo/src/az_aztec.h
```

在 `FORTRAN_DISABLED` 条件下，AztecOO 将 Fortran 例程名映射到 C fallback 函数：

```c
#else /* FORTRAN_DISABLED*/
#   define AZ_FNROOT_F77                 az_fnroot_c
#   define MC64AD_F77                    mc64ad_c
#   define AZ_RCM_F77                    az_rcm_c
#endif /* ndef FORTRAN_DISABLED */
```

但同一头文件中的外部函数声明只在未禁用 Fortran 时启用：

```c
#ifndef FORTRAN_DISABLED
extern void AZ_FNROOT_F77(int *,int *,int *,int *, int *, int *, int *);
extern void AZ_RCM_F77(int *, int *,int *, int *,int *, int *, int *);
#endif /* ndef FORTRAN_DISABLED */
```

实际 C fallback 函数定义存在：

```text
artifacts/source/Trilinos-14.4/packages/aztecoo/src/az_c_reorder.c
```

对应函数：

```c
int az_rcm_c(integer *root, integer *xadj, integer *adjncy,
             integer *mask, integer *perm, integer *ccsize, integer *deg)

int az_fnroot_c(integer *root, integer *xadj, integer *adjncy,
                integer *mask, integer *nlvl, integer *xls, integer *ls)
```

其中 `integer` 在该文件中为：

```c
typedef int integer;
```

因此在本构建的 `Trilinos_ENABLE_Fortran=OFF` 路径下，宏调用会落到 `az_fnroot_c` / `az_rcm_c`，但当前编译单元在调用前没有看到相应函数声明。GCC 15 将 implicit function declaration 视为错误，导致编译失败。

### 判断

阶段 3C 仍未通过，但已有正向推进：

- KokkosKernels `sort_option` 补丁有效；
- 当前失败点从 KokkosKernels 转移到 AztecOO；
- 问题仍属于 Trilinos 14.4 老源码在新编译器下暴露的 C 声明完整性问题；
- 不是 BLAS/LAPACK、SuiteSparse、MPI、Fortran 或链接问题。

### 建议处置

建议继续采用最小源码补丁：在 `FORTRAN_DISABLED` 分支下为 C fallback 函数补充外部声明。

建议补丁位置：

```text
artifacts/source/Trilinos-14.4/packages/aztecoo/src/az_aztec.h
```

建议把声明区从：

```c
#ifndef FORTRAN_DISABLED
extern void AZ_FNROOT_F77(int *,int *,int *,int *, int *, int *, int *);

extern void MC64AD_F77(int *, int *, int *, int *, int *, double*,
                    int *, int *, int *, int *, int *, double*,
                    int *, int *);

extern void AZ_RCM_F77(int *, int *,int *, int *,int *, int *, int *);
#endif /* ndef FORTRAN_DISABLED */
```

调整为：

```c
#ifndef FORTRAN_DISABLED
extern void AZ_FNROOT_F77(int *,int *,int *,int *, int *, int *, int *);

extern void MC64AD_F77(int *, int *, int *, int *, int *, double*,
                    int *, int *, int *, int *, int *, double*,
                    int *, int *);

extern void AZ_RCM_F77(int *, int *,int *, int *,int *, int *, int *);
#else
extern int AZ_FNROOT_F77(int *,int *,int *,int *, int *, int *, int *);
extern int AZ_RCM_F77(int *, int *,int *, int *,int *, int *, int *);
#endif /* ndef FORTRAN_DISABLED */
```

这里使用 `int` 返回类型，是为了匹配 `az_c_reorder.c` 中 f2c 生成的 C fallback 函数定义。当前调用点忽略返回值。

### 下一步

先暂停 Trilinos 编译。待确认是否允许对 AztecOO 头文件应用该第二个最小补丁。

若确认应用补丁，补丁后仍无需重新配置 CMake，直接继续：

```bash
cmake --build "$xyce_trilinos_build" --parallel 2
```

## 2026-07-22：阶段 3C Trilinos AztecOO 最小源码补丁已应用

### 用户确认

用户确认：

```text
允许应用 AztecOO 最小源码补丁
```

### 实际修改

已修补当前 Trilinos 源码树：

```text
artifacts/source/Trilinos-14.4/packages/aztecoo/src/az_aztec.h
```

在 AztecOO auxiliary routine 声明区，为 `FORTRAN_DISABLED` 分支补充 C fallback 函数声明：

```c
#else
extern int AZ_FNROOT_F77(int *,int *,int *,int *, int *, int *, int *);
extern int AZ_RCM_F77(int *, int *,int *, int *,int *, int *, int *);
#endif /* ndef FORTRAN_DISABLED */
```

### 补丁理由

当前构建关闭 Fortran：

```cmake
Trilinos_ENABLE_Fortran=OFF
```

因此 `AZ_FNROOT_F77` 和 `AZ_RCM_F77` 宏会分别映射到：

```c
az_fnroot_c
az_rcm_c
```

这些 C fallback 函数定义存在于：

```text
artifacts/source/Trilinos-14.4/packages/aztecoo/src/az_c_reorder.c
```

且返回类型为 `int`。补丁只补充缺失的函数原型声明，不改变调用逻辑和算法实现。

### 可复现补丁

由于 `artifacts/source/*` 被 `.gitignore` 忽略，当前源码树中的改动不会自然进入 git 跟踪。

为保证后续可复现，已保存补丁文件：

```text
notes/build-and-install/patches/trilinos-14.4-aztecoo-fortran-disabled-c-fallback-prototypes.patch
```

如果将来重新解压 Trilinos 源码，可在源码根目录应用：

```bash
cd /home/eda/my_lab/projects/study/xyce_study/artifacts/source/Trilinos-14.4
patch -p1 < /home/eda/my_lab/projects/study/xyce_study/notes/build-and-install/patches/trilinos-14.4-aztecoo-fortran-disabled-c-fallback-prototypes.patch
```

### 下一步

无需重新配置 Trilinos CMake。请继续执行：

```bash
cmake --build "$xyce_trilinos_build" --parallel 2
```

若继续失败，仍然只回传第一处真实错误即可。

## 2026-07-22：阶段 3C Trilinos 第三次编译失败，AztecOO 继续暴露 C fallback 声明缺失

### 用户反馈的结果

应用 AztecOO `az_fnroot_c` / `az_rcm_c` 原型补丁后，Trilinos 编译继续推进，但仍在 AztecOO 目标中失败。

新的第一处真实错误：

```text
artifacts/source/Trilinos-14.4/packages/aztecoo/src/az_aztec.h:631:24:
error: implicit declaration of function ‘az_dlaic1_c’ [-Wimplicit-function-declaration]
```

触发编译单元：

```text
packages/aztecoo/src/CMakeFiles/aztecoo.dir/az_gmres.c.o
```

对应调用点：

```text
artifacts/source/Trilinos-14.4/packages/aztecoo/src/az_gmres.c:426
```

构建同时显示其他目标仍可继续推进，例如 `epetraext` 已完成：

```text
[45%] Built target epetraext
```

### Codex 只读复核

在 `FORTRAN_DISABLED` 条件下，AztecOO 将 LAPACK auxiliary routine 宏映射到 C fallback 函数：

```c
#define AZ_DLASWP_F77  az_dlaswp_c
#define AZ_DLAIC1_F77  az_dlaic1_c
```

但对应原型声明只在未禁用 Fortran 时启用：

```c
#ifndef FORTRAN_DISABLED
void PREFIX AZ_DLASWP_F77(int *, double *, int *, int *, int *, int *, int *);

void PREFIX AZ_DLAIC1_F77(int * , int *, double *, double *, double *, double *,
                          double *, double *, double *);
...
#endif /* FORTRAN_DISABLED */
```

实际 C fallback 函数定义存在：

```text
artifacts/source/Trilinos-14.4/packages/aztecoo/src/az_c_util.c
```

对应函数：

```c
int az_dlaic1_c(integer *job, integer *j, doublereal *x,
                doublereal *sest, doublereal *w, doublereal *gamma,
                doublereal *sestpr, doublereal *s, doublereal *c__)

int az_dlaswp_c(integer *n, doublereal *a, integer *lda,
                integer *k1, integer *k2, integer *ipiv, integer *incx)
```

其中 `integer` 为 `int`，`doublereal` 为 `double`。

### 判断

阶段 3C 仍未通过，但这次失败与上一处 `az_fnroot_c` / `az_rcm_c` 属于同一类：

- 当前构建关闭 Fortran；
- AztecOO 使用 C fallback；
- C fallback 函数存在；
- 头文件没有在 `FORTRAN_DISABLED` 分支下暴露对应函数原型；
- GCC 15 拒绝 implicit function declaration。

这继续说明当前路线是正确的：不是依赖或链接错，而是 Trilinos 14.4 老 C/F2C 兼容层需要补齐声明。

### 建议处置

建议扩展 AztecOO 最小补丁，在 `az_aztec.h` 的 LAPACK auxiliary routine 声明块中，为 `FORTRAN_DISABLED` 分支补充 double-precision C fallback 原型。

建议补丁位置：

```text
artifacts/source/Trilinos-14.4/packages/aztecoo/src/az_aztec.h
```

建议把声明块从：

```c
#ifndef FORTRAN_DISABLED
void PREFIX AZ_DLASWP_F77(int *, double *, int *, int *, int *, int *, int *);

void PREFIX AZ_DLAIC1_F77(int * , int *, double *, double *, double *, double *,
                          double *, double *, double *);
void PREFIX AZ_SLASWP_F77(int *, float *, int *, int *, int *, int *, int *);

void PREFIX AZ_SLAIC1_F77(int * , int *, float *, float *, float *, float *,
                          float *, float *, float *);
#endif /* FORTRAN_DISABLED */
```

调整为：

```c
#ifndef FORTRAN_DISABLED
void PREFIX AZ_DLASWP_F77(int *, double *, int *, int *, int *, int *, int *);

void PREFIX AZ_DLAIC1_F77(int * , int *, double *, double *, double *, double *,
                          double *, double *, double *);
void PREFIX AZ_SLASWP_F77(int *, float *, int *, int *, int *, int *, int *);

void PREFIX AZ_SLAIC1_F77(int * , int *, float *, float *, float *, float *,
                          float *, float *, float *);
#else
extern int AZ_DLASWP_F77(int *, double *, int *, int *, int *, int *, int *);
extern int AZ_DLAIC1_F77(int *, int *, double *, double *, double *, double *,
                         double *, double *, double *);
#endif /* FORTRAN_DISABLED */
```

这里不补 `AZ_SLASWP_F77` / `AZ_SLAIC1_F77` 的 C fallback，因为在当前 `FORTRAN_DISABLED` 分支下没有定义对应宏，也没有发现对应 C fallback 函数定义；只补当前实际映射到 C fallback 的 double-precision 例程。

### 下一步

先暂停 Trilinos 编译。待确认是否允许扩展 AztecOO 最小补丁。

若确认应用补丁，补丁后仍无需重新配置 CMake，直接继续：

```bash
cmake --build "$xyce_trilinos_build" --parallel 2
```

## 2026-07-22：阶段 3C Trilinos AztecOO fallback 原型补丁已扩展

### 用户确认

用户确认：

```text
允许扩展 AztecOO fallback 原型补丁
```

### 实际修改

已继续修补当前 Trilinos 源码树：

```text
artifacts/source/Trilinos-14.4/packages/aztecoo/src/az_aztec.h
```

在 LAPACK auxiliary routine 声明块中，为 `FORTRAN_DISABLED` 分支补充 double-precision C fallback 原型：

```c
#else
extern int AZ_DLASWP_F77(int *, double *, int *, int *, int *, int *, int *);
extern int AZ_DLAIC1_F77(int *, int *, double *, double *, double *, double *,
                         double *, double *, double *);
#endif /* FORTRAN_DISABLED */
```

### 补丁理由

当前构建关闭 Fortran：

```cmake
Trilinos_ENABLE_Fortran=OFF
```

因此：

```c
AZ_DLASWP_F77  -> az_dlaswp_c
AZ_DLAIC1_F77  -> az_dlaic1_c
```

实际 C fallback 函数存在于：

```text
artifacts/source/Trilinos-14.4/packages/aztecoo/src/az_c_util.c
```

且返回类型为 `int`。补丁只补充函数原型，不改变算法实现。

本次没有补充 `AZ_SLASWP_F77` / `AZ_SLAIC1_F77` 的 C fallback 原型，因为当前 `FORTRAN_DISABLED` 分支并未定义对应宏，源码中也未发现对应 C fallback 函数定义。

### 可复现补丁

已扩展同一个 AztecOO 补丁文件：

```text
notes/build-and-install/patches/trilinos-14.4-aztecoo-fortran-disabled-c-fallback-prototypes.patch
```

该补丁现在覆盖两组 `FORTRAN_DISABLED` C fallback 原型：

- `AZ_DLASWP_F77` / `AZ_DLAIC1_F77`
- `AZ_FNROOT_F77` / `AZ_RCM_F77`

如果将来重新解压 Trilinos 源码，可在源码根目录应用：

```bash
cd /home/eda/my_lab/projects/study/xyce_study/artifacts/source/Trilinos-14.4
patch -p1 < /home/eda/my_lab/projects/study/xyce_study/notes/build-and-install/patches/trilinos-14.4-aztecoo-fortran-disabled-c-fallback-prototypes.patch
```

### 下一步

无需重新配置 Trilinos CMake。请继续执行：

```bash
cmake --build "$xyce_trilinos_build" --parallel 2
```

若继续失败，仍然只回传第一处真实错误即可。

## 2026-07-22：阶段 3C Trilinos 第四次编译失败，AztecOO `az_c_util.c` 缺少 BLAS `sswap_` 原型

### 用户反馈的结果

应用扩展后的 AztecOO fallback 原型补丁后，Trilinos 编译继续推进。

新的第一处真实错误：

```text
artifacts/source/Trilinos-14.4/packages/aztecoo/src/az_c_util.c:58:35:
error: implicit declaration of function ‘sswap_’; did you mean ‘sswap_c’? [-Wimplicit-function-declaration]
```

触发编译单元：

```text
packages/aztecoo/src/CMakeFiles/aztecoo.dir/az_c_util.c.o
```

实际调用点：

```text
artifacts/source/Trilinos-14.4/packages/aztecoo/src/az_c_util.c:1148
```

构建日志显示其他目标仍继续向前，例如 Tpetra 已推进到约 52%：

```text
[52%] Building CXX object packages/tpetra/core/src/CMakeFiles/tpetra.dir/...
```

### Codex 只读复核

`az_c_util.c` 顶部定义了 BLAS 符号名宏：

```c
#define SSWAP_F77 F77_BLAS_MANGLE(sswap,SSWAP)
```

在当前生成的配置中：

```c
#define F77_BLAS_MANGLE(name,NAME) name ## _
```

因此：

```c
SSWAP_F77 -> sswap_
```

Cadence BLAS 中存在该符号：

```text
0000000000087d80 T sswap_
```

但 `az_slaswp_c` 函数内部的局部声明写成了：

```c
extern /* Subroutine */ int sswap_c(integer *, real *, integer *, real *, integer *);
```

实际调用却是：

```c
SSWAP_F77(n, &a[i__ + a_dim1], lda, &a[ip + a_dim1], lda);
```

也就是说，声明的是 `sswap_c`，调用的是 `SSWAP_F77`，后者展开为 `sswap_`。GCC 15 在看到 `sswap_` 调用时没有对应原型，于是报 implicit function declaration。

### 判断

阶段 3C 仍未通过。

这次问题和前几次仍然属于同一大类：Trilinos 14.4 / AztecOO 老 C/F2C 兼容代码在新编译器下暴露出声明不完整或声明名不一致的问题。

但这次细节略有不同：

- 前几次是 `FORTRAN_DISABLED` 下 C fallback 函数存在，但头文件没有暴露原型；
- 这次是 `az_c_util.c` 局部声明写成了 `sswap_c`，而实际调用走 `SSWAP_F77` 宏，即真实 BLAS 符号 `sswap_`；
- BLAS 符号本身存在，不是 BLAS 库缺失。

### 建议处置

建议继续采用最小源码补丁：把 `az_c_util.c` 中 `az_slaswp_c` 函数内的局部 extern 声明从 `sswap_c` 改为 `SSWAP_F77`。

建议补丁位置：

```text
artifacts/source/Trilinos-14.4/packages/aztecoo/src/az_c_util.c
```

建议把：

```c
extern /* Subroutine */ int sswap_c(integer *, real *, integer *, real *,
  integer *);
```

改成：

```c
extern /* Subroutine */ int SSWAP_F77(integer *, real *, integer *, real *,
  integer *);
```

这样声明和调用会通过同一个宏名 `SSWAP_F77` 绑定到 `sswap_`，与当前 BLAS name mangling 一致。

### 下一步

先暂停 Trilinos 编译。待确认是否允许应用 AztecOO `az_c_util.c` 的 `SSWAP_F77` 最小补丁。

若确认应用补丁，补丁后仍无需重新配置 CMake，直接继续：

```bash
cmake --build "$xyce_trilinos_build" --parallel 2
```

## 2026-07-22：阶段 3C Trilinos AztecOO `az_c_util.c` `SSWAP_F77` 最小补丁已应用

### 用户确认

用户确认：

```text
允许应用 AztecOO az_c_util.c SSWAP_F77 最小补丁
```

### 实际修改

已修补当前 Trilinos 源码树：

```text
artifacts/source/Trilinos-14.4/packages/aztecoo/src/az_c_util.c
```

将 `az_slaswp_c` 内部局部 extern 声明从：

```c
extern /* Subroutine */ int sswap_c(integer *, real *, integer *, real *,
  integer *);
```

改为：

```c
extern /* Subroutine */ int SSWAP_F77(integer *, real *, integer *, real *,
  integer *);
```

### 补丁理由

`az_c_util.c` 中定义：

```c
#define SSWAP_F77 F77_BLAS_MANGLE(sswap,SSWAP)
```

当前配置中：

```c
#define F77_BLAS_MANGLE(name,NAME) name ## _
```

因此 `SSWAP_F77` 展开为 BLAS 符号：

```c
sswap_
```

而实际调用也使用：

```c
SSWAP_F77(...)
```

原源码声明的是 `sswap_c`，和实际调用符号不一致。改为声明 `SSWAP_F77` 后，声明和调用都经由同一个宏展开，避免 GCC 15 报 `sswap_` implicit declaration。

### 可复现补丁

由于 `artifacts/source/*` 被 `.gitignore` 忽略，当前源码树中的改动不会自然进入 git 跟踪。

为保证后续可复现，已保存补丁文件：

```text
notes/build-and-install/patches/trilinos-14.4-aztecoo-az-c-util-sswap-f77-prototype.patch
```

如果将来重新解压 Trilinos 源码，可在源码根目录应用：

```bash
cd /home/eda/my_lab/projects/study/xyce_study/artifacts/source/Trilinos-14.4
patch -p1 < /home/eda/my_lab/projects/study/xyce_study/notes/build-and-install/patches/trilinos-14.4-aztecoo-az-c-util-sswap-f77-prototype.patch
```

### 下一步

无需重新配置 Trilinos CMake。请继续执行：

```bash
cmake --build "$xyce_trilinos_build" --parallel 2
```

若继续失败，仍然只回传第一处真实错误即可。

## 2026-07-22：阶段 3C Trilinos 编译通过，尚未安装

### 用户反馈的结果

使用更高并发重新执行 Trilinos build 后，构建到 100% 并完成最终目标：

```text
[100%] Built target stokhos_amesos2
[100%] Built target trilinoscouplings
```

用户随后执行错误检索：

```bash
rg -n "error:|fatal error|undefined reference|collect2|ld:|Error [0-9]|FAILED" build/logs/trilinos-build-j8.log | head -n 40
```

未反馈任何错误输出。

### Codex 只读复核

日志错误检索无输出，说明 `trilinos-build-j8.log` 中未匹配到常见编译/链接错误模式。

关键库已在 build tree 中生成：

```text
build/deps/xyce-7.10-serial-release/trilinos/packages/amesos2/src/libamesos2.a
build/deps/xyce-7.10-serial-release/trilinos/packages/amesos/src/libamesos.a
build/deps/xyce-7.10-serial-release/trilinos/packages/aztecoo/src/libaztecoo.a
build/deps/xyce-7.10-serial-release/trilinos/packages/belos/src/libbelos.a
build/deps/xyce-7.10-serial-release/trilinos/packages/epetraext/src/libepetraext.a
build/deps/xyce-7.10-serial-release/trilinos/packages/nox/src/libnox.a
build/deps/xyce-7.10-serial-release/trilinos/packages/trilinoscouplings/src/libtrilinoscouplings.a
```

但安装前缀中尚未出现新的 Trilinos CMake package 配置：

```text
out/deps/xyce-7.10-serial-release/lib/cmake/Trilinos/TrilinosConfig.cmake
```

检查结果：

```text
installed TrilinosConfig not present yet
```

### 判断

阶段 3C 的 build 子步骤通过。

当前状态是：

```text
Trilinos configured: yes
Trilinos built:      yes
Trilinos installed:  no
```

因此还不能进入 Xyce 配置阶段。Xyce 后续需要通过 install prefix 查找 Trilinos，因此必须先执行 Trilinos install。

### 下一步

进入阶段 3D：安装 Trilinos。

建议继续保留日志：

```bash
cd /home/eda/my_lab/projects/study/xyce_study

mkdir -p build/logs

set -o pipefail
cmake --install "$xyce_trilinos_build" 2>&1 | tee build/logs/trilinos-install.log
```

安装完成后检查：

```bash
test -f "$xyce_deps_prefix/lib/cmake/Trilinos/TrilinosConfig.cmake" && echo "TrilinosConfig installed"

rg -n 'Trilinos_VERSION|Trilinos_PACKAGE_LIST|Trilinos_(C|CXX)_COMPILER|Trilinos_ENABLE_Fortran|Trilinos_MPI_EXEC' \
  "$xyce_deps_prefix/lib/cmake/Trilinos/TrilinosConfig.cmake"

find "$xyce_deps_prefix" -maxdepth 4 -type f \( \
  -name 'libtrilinoscouplings.*' -o \
  -name 'libaztecoo.*' -o \
  -name 'libnox.*' -o \
  -name 'libamesos.*' -o \
  -name 'libamesos2.*' -o \
  -name 'libbelos.*' -o \
  -name 'libepetraext.*' \
\) | sort
```

## 2026-07-22：阶段 3D Trilinos 安装通过

### 用户反馈的结果

Trilinos 安装前缀中已经出现 CMake package 配置：

```text
TrilinosConfig installed
```

实际位置：

```text
out/deps/xyce-7.10-serial-release/lib/cmake/Trilinos/TrilinosConfig.cmake
```

### TrilinosConfig 关键内容

编译器路径正确，均为本轮固定的 GCC toolset 15：

```cmake
Trilinos_CXX_COMPILER=/opt/rh/gcc-toolset-15/root/usr/bin/g++
Trilinos_C_COMPILER=/opt/rh/gcc-toolset-15/root/usr/bin/gcc
```

版本正确：

```cmake
Trilinos_VERSION=14.4
```

MPI 执行器为空，符合 serial build 预期：

```cmake
Trilinos_MPI_EXEC=""
```

包列表包含 Xyce 所需关键包：

```text
TrilinosCouplings
ROL
Stokhos
NOX
Amesos2
Belos
Ifpack
Amesos
AztecOO
Tpetra
EpetraExt
Triutils
Epetra
Sacado
KokkosKernels
Teuchos
Kokkos
```

### 已安装关键库

安装前缀中已出现关键静态库：

```text
out/deps/xyce-7.10-serial-release/lib/libamesos2.a
out/deps/xyce-7.10-serial-release/lib/libamesos.a
out/deps/xyce-7.10-serial-release/lib/libaztecoo.a
out/deps/xyce-7.10-serial-release/lib/libbelos.a
out/deps/xyce-7.10-serial-release/lib/libepetraext.a
out/deps/xyce-7.10-serial-release/lib/libnox.a
out/deps/xyce-7.10-serial-release/lib/libtrilinoscouplings.a
```

### 判断

阶段 3D 通过。

当前依赖层状态：

```text
SuiteSparse configured: yes
SuiteSparse built:      yes
SuiteSparse installed:  yes

Trilinos configured:    yes
Trilinos built:         yes
Trilinos installed:     yes
```

因此可以进入阶段 4：以最小选项配置 Xyce 本体。

### 下一步

进入阶段 4 前，先设置：

```bash
xyce_trilinos_prefix="$xyce_deps_prefix"
```

然后配置 Xyce，并仅检查 CMake cache，不要直接编译。

## 2026-07-22：阶段 4 Xyce 首次配置完成，但需修正最小开关

### 用户反馈的结果

Xyce CMake 配置已经生成 `CMakeCache.txt`，关键 cache 输出如下：

```cmake
BISON_EXECUTABLE=/home/eda/.local/xyce-tools/bin/bison
BUILD_SHARED_LIBS=OFF
BUILD_TESTING=OFF
CMAKE_BUILD_TYPE=Release
CMAKE_CXX_COMPILER=/opt/rh/gcc-toolset-15/root/usr/bin/g++
CMAKE_C_COMPILER=/opt/rh/gcc-toolset-15/root/usr/bin/gcc
CMAKE_INSTALL_PREFIX=/home/eda/my_lab/projects/study/xyce_study/out/xyce-7.10-serial-release
FLEX_EXECUTABLE=/home/eda/.local/xyce-tools/bin/flex
Trilinos_DIR=/home/eda/my_lab/projects/study/xyce_study/out/deps/xyce-7.10-serial-release/lib/cmake/Trilinos
Trilinos_ROOT=/home/eda/my_lab/projects/study/xyce_study/out/deps/xyce-7.10-serial-release
Xyce_PARALLEL_MPI=OFF
Xyce_PLUGIN_SUPPORT=OFF
Xyce_REGRESSION=OFF
Xyce_USE_FFT=OFF
```

### 通过项

以下项目符合本轮目标：

- 构建类型为 `Release`；
- C/C++ 编译器均为 GCC toolset 15；
- Xyce 安装前缀为本项目专属 `out/xyce-7.10-serial-release`；
- Trilinos 指向刚安装的本项目依赖前缀；
- `Xyce_PARALLEL_MPI=OFF`；
- `Xyce_USE_FFT=OFF`；
- `Xyce_PLUGIN_SUPPORT=OFF`；
- `BUILD_TESTING=OFF`；
- `BUILD_SHARED_LIBS=OFF`；
- flex/bison 指向本项目工具路径。

CMake build system 已生成：

```text
build/xyce-7.10-serial-release/Makefile
```

### 需修正项

进一步只读复核发现，以下选项不符合“最小配置”口径：

```cmake
Xyce_ADMS_MODELS=TRUE
Xyce_NEURON_MODELS=TRUE
Xyce_TEST_BINARIES=ON
```

原因：

- `Xyce_TEST_BINARIES` 在 Xyce 7.10 的 `feature_modes.cmake` 中默认 `ON`，会执行 `add_subdirectory(src/test)`；
- `Xyce_ADMS_MODELS` 和 `Xyce_NEURON_MODELS` 在对应源码目录存在时默认 `TRUE`；
- 当前源码树中确实存在：

```text
vendor/Xyce-7.10.0/src/DeviceModelPKG/ADMS
vendor/Xyce-7.10.0/src/DeviceModelPKG/NeuronModels
```

这不是配置失败，但它偏离了本轮的“serial + Release + no-plugin + no-FFT + no-test + minimal model surface”目标。

### 判断

阶段 4 尚不通过。

当前状态是：

```text
Xyce configured: yes
Xyce minimal cache accepted: no
Xyce build allowed: no
```

不要直接编译。需要在同一个 Xyce build tree 上重新运行 CMake，显式关闭这些默认开启的可选组件。

### 修正命令

建议重新执行配置命令，补充最小开关：

```bash
cmake -S "$xyce_source" -B "$xyce_build" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER="$xyce_cc" \
  -DCMAKE_CXX_COMPILER="$xyce_cxx" \
  -DCMAKE_INSTALL_PREFIX="$xyce_install" \
  -DTrilinos_ROOT="$xyce_trilinos_prefix" \
  -DXyce_PARALLEL_MPI=OFF \
  -DXyce_USE_FFT=OFF \
  -DXyce_PLUGIN_SUPPORT=OFF \
  -DXyce_ADMS_MODELS=OFF \
  -DXyce_NEURON_MODELS=OFF \
  -DXyce_NONFREE_MODELS=OFF \
  -DXyce_RAD_MODELS=OFF \
  -DBUILD_TESTING=OFF \
  -DXyce_TEST_BINARIES=OFF \
  -DXyce_REGRESSION=OFF \
  -DXyce_GTEST_UNIT_TESTS=OFF \
  -DBUILD_SHARED_LIBS=OFF \
  -DFLEX_EXECUTABLE=/home/eda/.local/xyce-tools/bin/flex \
  -DFLEX_INCLUDE_DIR=/usr/include \
  -DBISON_EXECUTABLE=/home/eda/.local/xyce-tools/bin/bison
```

然后复查：

```bash
rg -n '^(CMAKE_(C|CXX)_COMPILER|CMAKE_BUILD_TYPE|CMAKE_INSTALL_PREFIX|Trilinos_(ROOT|DIR)|Xyce_(PARALLEL_MPI|USE_FFT|PLUGIN_SUPPORT|ADMS_MODELS|NEURON_MODELS|NONFREE_MODELS|RAD_MODELS|REGRESSION|TEST_BINARIES|GTEST_UNIT_TESTS)|BUILD_(TESTING|SHARED_LIBS)|FLEX_EXECUTABLE|FLEX_INCLUDE_DIR|BISON_EXECUTABLE)' \
  "$xyce_build/CMakeCache.txt"
```

## 2026-07-22：阶段 4 Xyce 最小配置通过

### 用户反馈的结果

重新配置 Xyce 后，关键 CMake cache 输出如下：

```cmake
BISON_EXECUTABLE=/home/eda/.local/xyce-tools/bin/bison
BUILD_SHARED_LIBS=OFF
BUILD_TESTING=OFF
CMAKE_BUILD_TYPE=Release
CMAKE_CXX_COMPILER=/opt/rh/gcc-toolset-15/root/usr/bin/g++
CMAKE_C_COMPILER=/opt/rh/gcc-toolset-15/root/usr/bin/gcc
CMAKE_INSTALL_PREFIX=/home/eda/my_lab/projects/study/xyce_study/out/xyce-7.10-serial-release
FLEX_EXECUTABLE=/home/eda/.local/xyce-tools/bin/flex
FLEX_INCLUDE_DIR=/usr/include
Trilinos_DIR=/home/eda/my_lab/projects/study/xyce_study/out/deps/xyce-7.10-serial-release/lib/cmake/Trilinos
Trilinos_ROOT=/home/eda/my_lab/projects/study/xyce_study/out/deps/xyce-7.10-serial-release
Xyce_ADMS_MODELS=OFF
Xyce_GTEST_UNIT_TESTS=OFF
Xyce_NEURON_MODELS=OFF
Xyce_NONFREE_MODELS=OFF
Xyce_PARALLEL_MPI=OFF
Xyce_PLUGIN_SUPPORT=OFF
Xyce_RAD_MODELS=OFF
Xyce_REGRESSION=OFF
Xyce_TEST_BINARIES=OFF
Xyce_USE_FFT=OFF
```

### Codex 只读复核

Xyce build system 已生成：

```text
build/xyce-7.10-serial-release/Makefile
```

核心配置均符合本轮最小构建目标：

- `Release`；
- GCC toolset 15；
- install prefix 为 `out/xyce-7.10-serial-release`；
- Trilinos 指向 `out/deps/xyce-7.10-serial-release`；
- serial：`Xyce_PARALLEL_MPI=OFF`；
- FFT：`Xyce_USE_FFT=OFF`；
- plugin：`Xyce_PLUGIN_SUPPORT=OFF`；
- ADMS/Neuron/Nonfree/Rad 模型：均为 `OFF`；
- 测试、测试二进制、回归、GTest：均为 `OFF`；
- shared libs：`OFF`；
- flex/bison 路径明确。

只读扫描中出现：

```text
CMAKE_DLLTOOL=...-NOTFOUND
FL_LIBRARY=...-NOTFOUND
```

判断：

- `CMAKE_DLLTOOL-NOTFOUND` 对当前 Linux/GCC 非 Windows 构建不构成问题；
- `FL_LIBRARY-NOTFOUND` 未阻断配置，且当前已显式设置 `FLEX_EXECUTABLE` 与 `FLEX_INCLUDE_DIR`。若后续链接阶段出现 flex 相关 undefined reference，再回到该点处理；当前不作为阶段 4 阻塞项。

### 判断

阶段 4 通过。

当前状态：

```text
Xyce configured: yes
Xyce minimal cache accepted: yes
Xyce build allowed: yes
```

可以进入阶段 5：编译 Xyce。

### 下一步

建议使用并发 8，并保留日志：

```bash
cd /home/eda/my_lab/projects/study/xyce_study

mkdir -p build/logs

set -o pipefail
cmake --build "$xyce_build" --parallel 8 2>&1 | tee build/logs/xyce-build-j8.log
```

若失败，提取第一处真实错误：

```bash
rg -n "error:|fatal error|undefined reference|collect2|ld:|Error [0-9]|FAILED" build/logs/xyce-build-j8.log | head -n 60
```

若成功，检查：

```bash
test -x "$xyce_build/src/Xyce" && echo "Xyce build binary exists"
"$xyce_build/src/Xyce" -h | head -n 30
```

## 2026-07-22：阶段 5 Xyce 编译到最终链接失败，Cadence BLAS 缺少 KokkosKernels 所需符号

### 用户反馈的结果

Xyce 编译阶段已经生成大部分目标，`libxyce.a` 也已完成；失败发生在最终可执行文件 `src/Xyce` 的链接阶段。

错误检索输出：

```text
/opt/rh/gcc-toolset-15/root/usr/libexec/gcc/x86_64-redhat-linux/15/ld: /home/eda/my_lab/projects/study/xyce_study/out/deps/xyce-7.10-serial-release/lib/libkokkoskernels.a(KokkosBlas_Host_tpl.cpp.o): in function `KokkosBlas::Impl::HostBlas<float>::rotm(int, float*, int, float*, int, float const*)':
KokkosBlas_Host_tpl.cpp:(.text+0x171): undefined reference to `srotm_'
/opt/rh/gcc-toolset-15/root/usr/libexec/gcc/x86_64-redhat-linux/15/ld: /home/eda/my_lab/projects/study/xyce_study/out/deps/xyce-7.10-serial-release/lib/libkokkoskernels.a(KokkosBlas_Host_tpl.cpp.o): in function `KokkosBlas::Impl::HostBlas<double>::rotm(int, double*, int, double*, int, double const*)':
KokkosBlas_Host_tpl.cpp:(.text+0x6b1): undefined reference to `drotm_'
/opt/rh/gcc-toolset-15/root/usr/libexec/gcc/x86_64-redhat-linux/15/ld: /home/eda/my_lab/projects/study/xyce_study/out/deps/xyce-7.10-serial-release/lib/libkokkoskernels.a(KokkosBlas_Host_tpl.cpp.o): in function `KokkosBlas::Impl::HostBlas<float>::rotmg(float*, float*, float*, float const*, float*)':
KokkosBlas_Host_tpl.cpp:(.text+0x181): undefined reference to `srotmg_'
/opt/rh/gcc-toolset-15/root/usr/libexec/gcc/x86_64-redhat-linux/15/ld: /home/eda/my_lab/projects/study/xyce_study/out/deps/xyce-7.10-serial-release/lib/libkokkoskernels.a(KokkosBlas_Host_tpl.cpp.o): in function `KokkosBlas::Impl::HostBlas<double>::rotmg(double*, double*, double*, double const*, double*)':
KokkosBlas_Host_tpl.cpp:(.text+0x6c1): undefined reference to `drotmg_'
collect2: error: ld returned 1 exit status
```

### Codex 只读复核

Xyce 的实际链接命令位于：

```text
build/xyce-7.10-serial-release/src/CMakeFiles/Xyce.dir/link.txt
```

该链接命令已经包含当前 Trilinos 导出的 Cadence BLAS/LAPACK：

```text
/opt/cadence/IC231/tools.lnx86/lapack/lib/64bit/liblapack.so
/opt/cadence/IC231/tools.lnx86/lapack/lib/64bit/libblas.so
```

因此问题不是 BLAS/LAPACK 没有进入链接行，而是进入链接行的 Cadence `libblas.so` 缺少 KokkosKernels `HostBlas` 所需的 modified Givens routine。

Cadence BLAS 抽样符号：

```text
dgemm_
sgemm_
sswap_
```

缺少本次链接报错需要的：

```text
srotm_
drotm_
srotmg_
drotmg_
```

本机只读搜索发现 Mentor Calibre 安装树中存在 OpenBLAS 候选：

```text
/opt/mentor/Calibre2023/aok_cal_2023.2_16.9/pkgs/icv.aok/julia/1.5/lib/libopenblas.so
```

该 OpenBLAS 导出本次所需符号及基础 BLAS/LAPACK 符号：

```text
srotm_
srotmg_
drotm_
drotmg_
sswap_
sgemm_
dgemm_
dgeev_
dgesv_
```

其运行时依赖指向系统运行库：

```text
libgfortran.so.5 => /lib64/libgfortran.so.5
libquadmath.so.0 => /lib64/libquadmath.so.0
libgcc_s.so.1 => /lib64/libgcc_s.so.1
```

### 判断

阶段 5 未通过。

当前状态：

```text
XyceLib built:              yes
Xyce executable linked:     no
Xyce installed:             no
Cadence BLAS final verdict: rejected for this build
```

这次失败证实了早先 Cadence fallback 的风险：它足以通过 CMake 的基础 BLAS/LAPACK 探测，但不足以满足 Trilinos/KokkosKernels 静态库在最终 Xyce 链接时暴露出的完整符号需求。

### 下一步

不要手工修改 `src/CMakeFiles/Xyce.dir/link.txt`，也不要继续重复执行同一个 Xyce build。应回到 Trilinos TPL 配置层，把 BLAS/LAPACK 从 Cadence 切换到完整实现，然后重新安装 Trilinos 并重新配置 Xyce。

当前推荐的务实路线是先使用本机已有 Mentor OpenBLAS：

```bash
xyce_blas_lapack_libdir="/opt/mentor/Calibre2023/aok_cal_2023.2_16.9/pkgs/icv.aok/julia/1.5/lib"
xyce_blas="$xyce_blas_lapack_libdir/libopenblas.so"
xyce_lapack="$xyce_blas_lapack_libdir/libopenblas.so"

test -f "$xyce_blas"
nm -D "$xyce_blas" | rg ' (sgemm_|dgemm_|sswap_|srotm_|drotm_|srotmg_|drotmg_|dgesv_|dgeev_)$'
ldd "$xyce_blas"
```

验收通过后，重新配置 Trilinos 时清除旧的 BLAS/LAPACK cache，并显式指定 OpenBLAS。
