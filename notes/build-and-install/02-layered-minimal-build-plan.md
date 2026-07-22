# Xyce 7.10 分层构建：最小配置详细操作计划

记录日期：2026-07-22

最近更新：2026-07-22。已完成 GCC 工具链检查，详见
[03-gcc-toolchain-check.md](./03-gcc-toolchain-check.md)。

## 目标与边界

本计划的唯一交付物是一套可复现的 **Xyce 7.10 串行 Release 安装**：

```text
out/xyce-7.10-serial-release/bin/Xyce
```

它用于普通 netlist 和后续源码阅读中的小实验，而不是一次性开启所有能力。此次最小配置明确排除：

- MPI 分布式并行；
- FFTW 与 Harmonic Balance 所需的 FFT 支持；
- Xyce/ADMS Verilog-A 用户插件；
- GoogleTest、完整回归套件、辐射模型和非自由模型；
- Debug、共享库和打包安装器。

采用**分层构建**，不使用 `Xyce_USE_SUPERBUILD=ON`：

```text
OpenBLAS（含 LAPACK，项目专用数值库）
  -> SuiteSparse（只需 suitesparse_config + AMD）
  -> Trilinos 14.4（按 Xyce 提供的 initial cache 选择包）
  -> Xyce 7.10（串行 Release 最小功能）
```

这样每一层都是独立、可审计、可重编的安装，依赖故障不会被 SuperBuild 的多层日志掩盖。

## 事实依据与本机起点

### 来自本地 Xyce 7.10 源码的事实

- `INSTALL.md` 指定 CMake 为推荐构建入口，Autotools 已弃用；
- 需要 flex 2.6+、bison 3.3+、BLAS、LAPACK、SuiteSparse（AMD）和 Trilinos；
- Xyce 7.10 的常规手册指定 Trilinos 最低为 14.4；
- `cmake/trilinos/trilinos-base.cmake` 已列出 Xyce 所需的 Trilinos package 集合；
- Xyce 配置会强制查找 `FLEX 2.6`、`BISON 3.3` 和 Trilinos；
- Xyce 的顶层 `CMakeLists.txt` 要求 CMake 3.22+。

### 已做的只读检查（2026-07-22）

| 项目 | 观察结果 | 对本计划的含义 |
| --- | --- | --- |
| Xyce 源码 | `vendor/Xyce-7.10.0/` | 目标源码固定，不再另行下载 |
| CMake | 3.26.5 | 满足源码的 3.22+ 要求 |
| make、flex、bison | 可用 | 仍须在执行阶段记录精确版本 |
| 默认 GCC/G++ | 8.5.0 | **低于 `INSTALL.md` 所列 GCC 9+ 基线**，不作为正式构建工具链 |
| GCC Toolset 15 | `/opt/rh/gcc-toolset-15/root/usr/bin/gcc` 与 `/opt/rh/gcc-toolset-15/root/usr/bin/g++`，版本 15.2.1 | **作为本计划推荐工具链** |
| Clang/Clang++ | 21.1.8 | 可作为备选，但本计划优先使用 GCC Toolset 15 |
| 已安装 Trilinos | `/home/eda/.local/xyce-deps/install/lib/cmake/Trilinos/TrilinosConfig.cmake`，版本为 14.4，记录显示由 `/usr/bin/gcc` 和 `/usr/bin/g++` 构建 | 与推荐 GCC 15 工具链不一致，不作为正式最小构建的复用目标 |
| 已安装 AMD | 同一前缀中存在 `lib64/libamd.*` | 依赖栈已有部分证据 |
| 旧 Xyce build | `build/` 为串行 Release cache，仅有 `src/libxyce.a`，未见最终 `Xyce` | 不作为本计划的目标 build tree |

### 第一条继续条件：固定 GCC Toolset 15 为专用工具链

当前系统默认 `gcc` / `g++` 仍为 8.5，但系统已经安装并验证可用 `gcc-toolset-15`。为获得“按上游前提构建”的结果，正式执行时固定使用以下绝对路径，并让 **SuiteSparse、Trilinos、Xyce 三层全部使用同一套 C/C++ 编译器**：

```sh
xyce_cc="/opt/rh/gcc-toolset-15/root/usr/bin/gcc"
xyce_cxx="/opt/rh/gcc-toolset-15/root/usr/bin/g++"
```

不要替换系统默认 `/usr/bin/gcc`，也不要通过 `alternatives` 改变全局 GCC。Xyce 只需要项目专用工具链；全局替换可能影响系统包、老 EDA 工具或其他项目。

现有 `/home/eda/.local/xyce-deps/install` 中的 Trilinos 14.4 由 GCC 8.5 构建。切换到 GCC 15 后，不应把这套 Trilinos 作为正式依赖复用；它只保留为历史参考或对照审计对象。

## 目录、命名与不覆盖规则

以下命令都假设从仓库根目录 `/home/eda/my_lab/projects/study/xyce_study` 执行。为避免误删和混用 cache，先只定义本任务变量：

```sh
xyce_workspace="/home/eda/my_lab/projects/study/xyce_study"
xyce_source="$xyce_workspace/vendor/Xyce-7.10.0"
xyce_deps_prefix="$xyce_workspace/out/deps/xyce-7.10-serial-release"
xyce_build="$xyce_workspace/build/xyce-7.10-serial-release"
xyce_install="$xyce_workspace/out/xyce-7.10-serial-release"
xyce_tpl_source="$xyce_workspace/artifacts/source"
xyce_tpl_build="$xyce_workspace/build/deps/xyce-7.10-serial-release"
xyce_blas_lapack_libdir="$xyce_deps_prefix/lib64"
xyce_blas="$xyce_blas_lapack_libdir/libopenblas.so"
xyce_lapack="$xyce_blas_lapack_libdir/libopenblas.so"
```

目标布局为：

```text
artifacts/source/                         # 上游压缩包或只读第三方源码归档
build/deps/xyce-7.10-serial-release/      # SuiteSparse、Trilinos 各自的 CMake build tree
out/deps/xyce-7.10-serial-release/        # OpenBLAS、SuiteSparse、Trilinos 的安装前缀
build/xyce-7.10-serial-release/           # 仅属于 Xyce 的 CMake build tree
out/xyce-7.10-serial-release/             # 最终 Xyce 安装前缀
```

`build/`、`out/` 和 `artifacts/source/` 已被本仓库忽略，适合保存本地构建物；`notes/` 只保存命令、版本、结果和诊断结论。

**保护规则：**

1. 不使用裸 `build/` 作为新目标，以免污染已有不完整 cache。
2. 若上述新目录已经存在且非空，先读取其中的 `CMakeCache.txt`、`install_manifest.txt` 和日志，确认归属；不要通过递归删除“清场”。
3. 每一层安装到自己的确定前缀；不要安装到 `/usr/local`，不要用 `sudo`。
4. 依赖前缀的编译器、CMake 参数、版本在重建前先记录到本专题的后续执行记录中。

## 阶段 0：冻结构建契约

### 操作

在开始下载、配置或编译之前，记录以下信息：

```sh
cmake --version
make --version | head -n 1
/opt/rh/gcc-toolset-15/root/usr/bin/gcc --version | head -n 1
/opt/rh/gcc-toolset-15/root/usr/bin/g++ --version | head -n 1
/home/eda/.local/xyce-tools/bin/flex --version
/home/eda/.local/xyce-tools/bin/bison --version
```

确定将实际使用的合规编译器绝对路径，并在后续所有 CMake 命令中固定它们：

```sh
xyce_cc="/opt/rh/gcc-toolset-15/root/usr/bin/gcc"
xyce_cxx="/opt/rh/gcc-toolset-15/root/usr/bin/g++"
```

本计划仍在 Trilinos 中显式关闭 `Trilinos_ENABLE_Fortran`；但 OpenBLAS 的 LAPACK 实现需要 Fortran 编译器。因此还需检查并固定与 GCC Toolset 15 匹配的 `gfortran`：

```sh
xyce_fc="/opt/rh/gcc-toolset-15/root/usr/bin/gfortran"
test -x "$xyce_fc" && "$xyce_fc" --version | head -n 1
```

若该文件不存在，应先由用户安装/取得 `gcc-toolset-15-gcc-gfortran`，再继续数值库层；不要退回系统 GCC 8 的 `gfortran`，也不要用 Cadence 的 Fortran 运行库混搭。

### 成功判据

- 已记录所有工具的版本和绝对路径；
- `xyce_cc`、`xyce_cxx` 指向同一发行版/工具链的合规编译器；
- `xyce_cc`、`xyce_cxx` 分别等于 `/opt/rh/gcc-toolset-15/root/usr/bin/gcc` 和 `/opt/rh/gcc-toolset-15/root/usr/bin/g++`；
- `xyce_fc` 是与 GCC Toolset 15 匹配的 `gfortran`；
- `xyce_blas`、`xyce_lapack` 最终都指向项目依赖前缀中的同一个 `libopenblas.so`；
- 已确认此次是 `serial + Release + static + no-plugin + no-FFT + no-test`。

### 停止条件

- 没有合规 C/C++ 编译器；
- 计划在中途切换编译器；
- 准备复用的依赖由其他编译器或 MPI 模式构建。

出现任一项时，先解决工具链选择；不要开始构建任何一层。

## 阶段 1：审计现有依赖，并决定是否重建

现有前缀 `/home/eda/.local/xyce-deps/install` 已提供 Trilinos 14.4 和 AMD 的证据。但 2026-07-22 的检查已确认该 Trilinos 记录的编译器为 `/usr/bin/gcc` 和 `/usr/bin/g++`，即 GCC 8.5。由于本计划推荐使用 GCC Toolset 15，正式最小构建默认进入阶段 2、3 重建受控依赖栈。

仍保留下面的只读审计步骤，目的不是复用，而是记录“为什么不复用”：

```sh
xyce_existing_deps="/home/eda/.local/xyce-deps/install"

test -f "$xyce_existing_deps/lib/cmake/Trilinos/TrilinosConfig.cmake"
test -f "$xyce_existing_deps/include/TrilinosConfig.cmake"
find "$xyce_existing_deps" -maxdepth 3 -type f \( -name 'libamd.*' -o -name 'libamd.so*' \)
rg -n 'Trilinos_VERSION|Trilinos_PACKAGE_LIST' \
  "$xyce_existing_deps/lib/cmake/Trilinos/TrilinosConfig.cmake"
```

随后从该 Trilinos 的安装记录或 `CMakeCache.txt` 摘录：

- `CMAKE_C_COMPILER`、`CMAKE_CXX_COMPILER` 是否与阶段 0 的工具链相同；
- `TPL_ENABLE_MPI=OFF` 或等价配置，即它是串行 Trilinos；
- 配置包含 Xyce cache 所需的 NOX、EpetraExt、Ifpack、AztecOO、Belos、Teuchos、Amesos/KLU、Sacado、Stokhos、ROL、Amesos2/KLU2/Basker 等能力；
- 使用的 AMD、BLAS 和 LAPACK 库仍可从该前缀或系统运行库路径找到。

### 分支决策

```text
Trilinos 14.4 + 所需 package + 串行 + 编译器一致
  -> 复用这个前缀，跳至阶段 4 配置 Xyce

任一项不满足，或其构建来源不可追溯
  -> 按阶段 2、3 重建受控依赖栈
```

对当前机器而言，该分支决策已经落在第二条：现有 Trilinos 与 GCC Toolset 15 不一致，所以正式构建应按阶段 2、3 在 `out/deps/...` 中创建新前缀。即使后续发现它是串行且包列表完整，也不改变这个工具链一致性结论。

## 阶段 2：构建 SuiteSparse 的最小子集（已配置，可继续执行）

### 输入与版本

根据本地 `INSTALL.md`，选择 SuiteSparse 7.8.3 或更新版本，且只构建：

- `suitesparse_config`
- `amd`

将第三方源码归档到 `artifacts/source/`，并在执行记录中写下版本、下载 URL 或 commit SHA、校验值。不要使用 Xyce SuperBuild 里旧的 SuiteSparse tag 代替这一常规路线。

### 配置

创建明确目录并用同一工具链配置：

```sh
xyce_suitesparse_source="$xyce_tpl_source/SuiteSparse-<verified-version>"
xyce_suitesparse_build="$xyce_tpl_build/suitesparse"

cmake -S "$xyce_suitesparse_source" -B "$xyce_suitesparse_build" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER="$xyce_cc" \
  -DCMAKE_CXX_COMPILER="$xyce_cxx" \
  -DCMAKE_INSTALL_PREFIX="$xyce_deps_prefix" \
  -DSUITESPARSE_ENABLE_PROJECTS="suitesparse_config;amd" \
  -DSUITESPARSE_USE_FORTRAN=OFF \
  -DSUITESPARSE_USE_OPENMP=OFF \
  -DSUITESPARSE_DEMOS=OFF \
  -DBUILD_TESTING=OFF \
  -DBUILD_SHARED_LIBS=ON \
  -DBUILD_STATIC_LIBS=ON
```

先阅读 CMake 输出和 `CMakeCache.txt`，确认安装前缀、编译器和项目选择无误，再继续。

对当前最小子集而言，`suitesparse_config` 与 `amd` 实际链接阶段不直接链接 BLAS/LAPACK。先前的配置曾传入 Cadence 路径并收到 `manually-specified but not used` warning；这不影响已生成的 SuiteSparse build tree，可直接完成 build/install。真正需要统一 BLAS/LAPACK 的主要是后续 Trilinos。

### 编译、安装与验收

首轮并行度使用保守的 2：

```sh
cmake --build "$xyce_suitesparse_build" --parallel 2
cmake --install "$xyce_suitesparse_build"
find "$xyce_deps_prefix" -maxdepth 3 -type f -name 'libamd.*'
```

验收要求是安装前缀中同时出现 AMD 头文件和库；如果库位于 `lib64/`，阶段 3 必须显式传递该路径。安装失败时先保留 build tree 和 `CMakeFiles/CMakeError.log`，不覆盖重配。

## 阶段 2.5：构建项目专用 OpenBLAS（含 LAPACK）

### 为什么新增这一层

先前仅为让 SuiteSparse 配置通过，临时指定了 Cadence IC231 中的 `libblas.so`、`liblapack.so`。这些库本身可用，但它们的运行时依赖 Cadence 私有的 `libgfortran`、`libquadmath` 和 `libgcc_s`，并且不处在本项目依赖前缀中。这会把最终 Trilinos/Xyce 的可运行性隐式绑定到 Cadence 安装及其运行时环境。

正式构建改为在 `$xyce_deps_prefix` 安装一份由 GCC Toolset 15 构建的 OpenBLAS。它同时提供 BLAS 和 LAPACK API；因此后续两个 TPL 都明确链接同一个 `libopenblas.so`。这是“干净”的含义：版本、编译器、Fortran 运行时和库路径都由本项目记录、控制和验证。

这不是把 Xyce 改为“并行构建”：OpenBLAS 的线程模型与 MPI 是两个独立维度。为使最小构建行为稳定且避免小规模线性代数的线程开销，本计划构建单线程 OpenBLAS（`USE_THREAD=0`，`USE_OPENMP=0`）。

### 前置条件与输入

确认工具链中存在 `xyce_fc` 后，获取一个固定的 OpenBLAS release archive（当前可选上游稳定版为 0.3.33；也可选择明确记录的较早稳定版），保存到 `artifacts/source/`。记录下载 URL、SHA-256 和 tag；不使用 `develop` 分支。

### 配置、编译和安装

OpenBLAS 的 Make 构建要求安装时重复 build 参数。因此先固定参数文件式变量，再在同一 shell 中执行：

```sh
xyce_openblas_source="$xyce_tpl_source/OpenBLAS-<verified-version>"
xyce_openblas_prefix="$xyce_deps_prefix"

make -C "$xyce_openblas_source" \
  CC="$xyce_cc" FC="$xyce_fc" \
  DYNAMIC_ARCH=1 USE_THREAD=0 USE_OPENMP=0 \
  NO_SHARED=0

make -C "$xyce_openblas_source" install \
  PREFIX="$xyce_openblas_prefix" \
  CC="$xyce_cc" FC="$xyce_fc" \
  DYNAMIC_ARCH=1 USE_THREAD=0 USE_OPENMP=0 \
  NO_SHARED=0
```

实际安装目录可能是 `lib/` 或 `lib64/`，不要猜测。安装后通过 `find` 取得 `libopenblas.so` 的父目录，并在当前 shell 明确设定：

```sh
xyce_openblas_so="$(find "$xyce_openblas_prefix" -type f -name 'libopenblas.so' -print -quit)"
test -n "$xyce_openblas_so" && test -f "$xyce_openblas_so" || exit 1
xyce_blas_lapack_libdir="$(dirname "$xyce_openblas_so")"
xyce_blas="$xyce_openblas_so"
xyce_lapack="$xyce_openblas_so"

printf '%s\\n' "$xyce_blas" "$xyce_lapack"
ldd "$xyce_openblas_so"
nm -D "$xyce_openblas_so" | rg ' (dgemm_|dgesv_)$'
```

验收要求：`dgemm_`（BLAS）和 `dgesv_`（LAPACK）均由同一 `libopenblas.so` 导出，且 `ldd` 中的 `libgfortran.so`、`libquadmath.so`、`libgcc_s.so` 来自 GCC Toolset 15，而不是 Cadence。若只存在 `libopenblas.a`、找不到 `dgesv_` 或出现混用运行时，停止并保留日志，不要进入 Trilinos。

## 阶段 3：构建 Xyce 所需的串行 Trilinos 14.4（当前推荐执行）

### 输入

获取并固定 `trilinos-release-14-4-branch` 对应的确定 commit 或发行归档，解压到：

```text
artifacts/source/Trilinos-14.4/
```

Xyce 提供的 initial cache 是这里的包选择依据：

```text
vendor/Xyce-7.10.0/cmake/trilinos/trilinos-base.cmake
```

不要手工把 `Trilinos_ENABLE_ALL_PACKAGES=ON` 打开；那会显著增加构建时间和依赖面，也偏离“最小 Xyce 依赖集”的目标。

### 配置

```sh
xyce_trilinos_source="$xyce_tpl_source/Trilinos-14.4"
xyce_trilinos_build="$xyce_tpl_build/trilinos"

cmake -S "$xyce_trilinos_source" -B "$xyce_trilinos_build" \
  -C "$xyce_source/cmake/trilinos/trilinos-base.cmake" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER="$xyce_cc" \
  -DCMAKE_CXX_COMPILER="$xyce_cxx" \
  -DTrilinos_ENABLE_Fortran=OFF \
  -DCMAKE_INSTALL_PREFIX="$xyce_deps_prefix" \
  -DAMD_LIBRARY_DIRS="$xyce_deps_prefix/lib64" \
  -DAMD_INCLUDE_DIRS="$xyce_deps_prefix/include" \
  -DBLAS_LIBRARY_DIRS="$xyce_blas_lapack_libdir" \
  -DLAPACK_LIBRARY_DIRS="$xyce_blas_lapack_libdir" \
  -DBLAS_LIBRARY_NAMES=openblas \
  -DLAPACK_LIBRARY_NAMES=openblas
```

这里显式关闭 Fortran 只是最小 Trilinos 构建的取舍，不表示 Xyce 不允许或不受益于带 Fortran 的 Trilinos。OpenBLAS 自身需要 `gfortran` 来编译所含 LAPACK，但这不等于打开 Trilinos 的 Fortran 接口。不要让 Trilinos 自动搜索到系统库或 Cadence 库；BLAS 与 LAPACK 都必须解析为阶段 2.5 安装的 `libopenblas.so`。

配置后检查：

```sh
rg -n '^(CMAKE_(C|CXX)_COMPILER|CMAKE_INSTALL_PREFIX|TPL_ENABLE_(AMD|BLAS|LAPACK|MPI)|Trilinos_ENABLE_(NOX|EpetraExt|Amesos|Sacado|Fortran))' \
  "$xyce_trilinos_build/CMakeCache.txt"
```

特别确认 `TPL_ENABLE_MPI=OFF`，且 AMD、BLAS、LAPACK 都是可用状态。

### 编译、安装与验收

```sh
cmake --build "$xyce_trilinos_build" --parallel 2
cmake --install "$xyce_trilinos_build"

test -f "$xyce_deps_prefix/lib/cmake/Trilinos/TrilinosConfig.cmake"
rg -n 'Trilinos_VERSION|Trilinos_PACKAGE_LIST' \
  "$xyce_deps_prefix/lib/cmake/Trilinos/TrilinosConfig.cmake"
```

验收通过必须同时满足：版本为 14.4、配置文件位于安装前缀、包列表包含阶段 1 所列关键包、CMake cache 显示串行配置。到这一步为止，仍没有开始构建 Xyce。

## 阶段 4：以最小选项配置 Xyce

### 选择依赖前缀

只有当阶段 1 的复用审计通过且编译器与阶段 0 完全一致时，才设置：

```sh
xyce_trilinos_prefix="/home/eda/.local/xyce-deps/install"
```

当前推荐路线是阶段 2、3 重建完成后设置：

```sh
xyce_trilinos_prefix="$xyce_deps_prefix"
```

### 配置命令

本机旧 cache 显示专用 flex/bison 位于 `/home/eda/.local/xyce-tools/bin/`。执行前先确认它们的版本满足要求；通过后采用如下明确配置：

```sh
cmake -S "$xyce_source" -B "$xyce_build" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER="$xyce_cc" \
  -DCMAKE_CXX_COMPILER="$xyce_cxx" \
  -DCMAKE_INSTALL_PREFIX="$xyce_install" \
  -DTrilinos_ROOT="$xyce_trilinos_prefix" \
  -DXyce_PARALLEL_MPI=OFF \
  -DXyce_USE_FFT=OFF \
  -DXyce_PLUGIN_SUPPORT=OFF \
  -DBUILD_TESTING=OFF \
  -DXyce_REGRESSION=OFF \
  -DXyce_GTEST_UNIT_TESTS=OFF \
  -DBUILD_SHARED_LIBS=OFF \
  -DFLEX_EXECUTABLE=/home/eda/.local/xyce-tools/bin/flex \
  -DFLEX_INCLUDE_DIR=/usr/include \
  -DBISON_EXECUTABLE=/home/eda/.local/xyce-tools/bin/bison
```

若专用工具不再可用，替换为阶段 0 记录的系统绝对路径；不要删除 `FLEX_INCLUDE_DIR` 后假设旧 cache 会自动修正。

### 配置验收

在发起编译前逐项检查：

```sh
rg -n '^(CMAKE_(C|CXX)_COMPILER|CMAKE_BUILD_TYPE|CMAKE_INSTALL_PREFIX|Trilinos_(ROOT|DIR)|Xyce_(PARALLEL_MPI|USE_FFT|PLUGIN_SUPPORT|REGRESSION)|BUILD_(TESTING|SHARED_LIBS)|FLEX_EXECUTABLE|BISON_EXECUTABLE)' \
  "$xyce_build/CMakeCache.txt"
```

应看到：

- `Release`；
- 选定的同一套 C/C++ 编译器；
- 新的、专属的安装前缀；
- 正确的 Trilinos 前缀；
- `Xyce_PARALLEL_MPI=OFF`；
- FFT、插件、测试、回归、共享库均为 `OFF`；
- flex 与 bison 的实际可执行文件路径。

若任何一项不同，删除的只能是这个新建的、已确认归属的 `xyce_build` 目录；修正参数后重新配置。不得修改旧的裸 `build/` 目录来“试试”。

## 阶段 5：编译并安装 Xyce

### 编译

第一次使用两个并行任务，方便读取第一处真实错误并避免大型模板编译吃满内存：

```sh
cmake --build "$xyce_build" --parallel 2
```

验收不能只看生成了 `libxyce.a`；必须确认最终可执行目标已完成：

```sh
test -x "$xyce_build/src/Xyce"
```

### 安装

```sh
cmake --install "$xyce_build"
test -x "$xyce_install/bin/Xyce"
find "$xyce_install" -maxdepth 2 -type f | sort
```

安装完成后保留 `$xyce_build/install_manifest.txt`。它是后续审计安装内容的依据；本计划不包含卸载或删除操作。

## 阶段 6：最小运行验收

### 二进制检查

```sh
"$xyce_install/bin/Xyce" -h
```

成功条件：进程以成功状态退出并显示命令帮助；若出现共享库找不到，先检查依赖库的 RPATH、安装前缀和动态链接器可见性，不要复制库文件到系统目录。

### 最小电阻电路冒烟测试

在一个明确的临时工作目录创建以下输入（文件名建议 `smoke-resistor.cir`）：

```spice
Xyce smoke test: 1 V source and 1 kOhm resistor
V1 1 0 DC 1
R1 1 0 1k
.OP
.PRINT OP V(1) I(V1)
.END
```

运行：

```sh
"$xyce_install/bin/Xyce" smoke-resistor.cir
```

成功条件：

- 运行完成且无 fatal error；
- 输出中存在 operating-point/solution summary；
- `V(1)` 接近 1 V；
- 通过电压源的电流量级为 1 mA（符号取决于 Xyce 的电流参考方向）。

这一步证明的不只是 binary 能启动，还证明 netlist 解析、器件注册、方程装配、线性/非线性求解和输出链至少完成了一次闭环。

## 阶段 7：归档与学习验收

完成后在本专题新增一次执行记录，至少包含：

- Xyce、OpenBLAS、SuiteSparse、Trilinos 的版本与来源/commit；
- CMake、C/C++/Fortran 编译器、flex、bison 的版本和绝对路径；
- 每层完整 configure/build/install 命令及其关键参数；
- 每层 build/install 的开始与结束时间、并行度；
- `CMakeCache.txt` 中的关键开关摘录；
- `Xyce -h` 和电阻冒烟测试的结果；
- 遇到的首个失败、根因和最终修正。

### 本轮掌握检查

在进入 MPI、FFTW 或 ADMS 前，能够独立回答下面两题，才算掌握最小分层构建：

1. 为什么不能让串行 Xyce 链接一套 MPI Trilinos？
2. 为什么“`libxyce.a` 已出现”不足以证明 Xyce 已构建、安装和可运行？

预期要点分别是“并行模式是构建期 ABI/通信层属性，必须一致”和“仍需最终链接、安装及 netlist 冒烟测试的证据”。

## 执行顺序总览

```text
0. 固定 GCC Toolset 15 的 gcc/g++（并为 OpenBLAS 补齐同工具集 gfortran）
1. 审计现有 Trilinos 14.4 / AMD 前缀，记录其 GCC 8.5 来源
2. SuiteSparse -> 2.5 OpenBLAS -> 3. Trilinos -> 4. 配置 Xyce
5. 审核 Xyce 的 CMake cache
6. 编译 Xyce -> 确认 build/src/Xyce
7. 安装 -> 确认 out/.../bin/Xyce -> 帮助与电阻冒烟测试
7. 记录可复现构建证据
```

## 下一步

当前已完成阶段 0、阶段 1 与阶段 2B（SuiteSparse 配置），尚未执行编译或安装。下一步可先完成 SuiteSparse 的 build/install；在进入 Trilinos 前，必须补齐 GCC Toolset 15 的 `gfortran` 并完成阶段 2.5 的 OpenBLAS build/install。完整的实际进度以 [04-layered-minimal-build-execution-log.md](./04-layered-minimal-build-execution-log.md) 为准。
