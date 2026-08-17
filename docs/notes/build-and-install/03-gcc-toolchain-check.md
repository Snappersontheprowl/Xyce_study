# GCC 工具链检查与更新建议

日期：2026-07-22

## 结论

推荐不要替换 Rocky Linux 8.10 的系统默认 `/usr/bin/gcc`。本项目的 Xyce 最小分层构建应使用已经安装好的 `gcc-toolset-15`，并在 SuiteSparse、Trilinos、Xyce 三层中固定同一组绝对路径：

```bash
xyce_cc="/opt/rh/gcc-toolset-15/root/usr/bin/gcc"
xyce_cxx="/opt/rh/gcc-toolset-15/root/usr/bin/g++"
```

如果只是进入一个临时交互 shell，也可以启用 toolset：

```bash
source /opt/rh/gcc-toolset-15/enable
```

但正式 CMake 配置时仍建议显式传入 `CMAKE_C_COMPILER` 和 `CMAKE_CXX_COMPILER`，避免 PATH 变化导致后续层误用 `/usr/bin/gcc`。

## 依据

Xyce 7.10.0 的 `INSTALL.md` 要求 C/C++ 编译器具备 C++17 支持，并给出 `gcc 9 or later` 作为示例基线。当前系统默认 GCC 是 8.5，低于这个基线。

已检查到系统中存在以下主要编译器：

| 工具 | 路径 | 版本 | 对本计划的判断 |
|---|---|---:|---|
| `gcc` | `/usr/bin/gcc` | 8.5.0 | 不推荐作为正式构建工具链 |
| `g++` | `/usr/bin/g++` | 8.5.0 | 不推荐作为正式构建工具链 |
| `cc` | `/usr/bin/cc` | 8.5.0 | 不推荐作为正式构建工具链 |
| `c++` | `/usr/bin/c++` | 8.5.0 | 不推荐作为正式构建工具链 |
| `gcc-toolset-15 gcc` | `/opt/rh/gcc-toolset-15/root/usr/bin/gcc` | 15.2.1 | 推荐用于本项目 |
| `gcc-toolset-15 g++` | `/opt/rh/gcc-toolset-15/root/usr/bin/g++` | 15.2.1 | 推荐用于本项目 |
| `clang` | `/usr/bin/clang` | 21.1.8 | 可作为备选，但本计划优先使用 GCC |
| `clang++` | `/usr/bin/clang++` | 21.1.8 | 可作为备选，但本计划优先使用 GCC |

同时确认 `gcc-toolset-15` 可以通过 `source /opt/rh/gcc-toolset-15/enable` 进入 PATH，且 `g++ 15.2.1` 能编译最小 C++17 程序。

## 对现有依赖的影响

当前已有依赖前缀：

```text
/home/eda/.local/xyce-deps/install
```

其中 Trilinos 14.4 的配置记录显示：

```cmake
set(Trilinos_CXX_COMPILER "/usr/bin/g++")
set(Trilinos_C_COMPILER "/usr/bin/gcc")
set(Trilinos_Fortran_COMPILER "")
set(Trilinos_VERSION "14.4")
```

这说明现有 Trilinos 是用系统 GCC 8.5 构建的。若 Xyce 改用 GCC 15，而 Trilinos 继续复用 GCC 8.5 构建产物，会破坏分层构建计划里的“编译器一致性”约束。

因此，切换到 `gcc-toolset-15` 后，推荐从依赖层重建：

1. SuiteSparse：使用 GCC 15。
2. Trilinos 14.4：使用 GCC 15，并保持 `Trilinos_ENABLE_Fortran=OFF`。
3. Xyce 7.10.0：使用同一组 GCC 15 绝对路径。

当前系统没有检测到 `gfortran`。这不阻塞最小串行构建，因为计划中 Trilinos 会显式关闭 Fortran。

## 推荐更新策略

首选策略是“启用已有新工具链”，而不是“升级系统默认 GCC”：

```bash
source /opt/rh/gcc-toolset-15/enable
gcc --version
g++ --version
```

然后在分层构建脚本或手工命令中固定：

```bash
-DCMAKE_C_COMPILER=/opt/rh/gcc-toolset-15/root/usr/bin/gcc
-DCMAKE_CXX_COMPILER=/opt/rh/gcc-toolset-15/root/usr/bin/g++
```

不建议把 `/usr/bin/gcc` 切换成 GCC 15。Rocky/RHEL 系发行版里，系统默认 GCC 常被系统包、内核模块、老 EDA 工具或兼容层假定为平台默认版本。Xyce 项目只需要一套构建专用编译器，不需要改变全局系统语义。

## 后续执行检查点

正式进入 `02-layered-minimal-build-plan.md` 的阶段 0 时，应先记录：

```bash
/opt/rh/gcc-toolset-15/root/usr/bin/gcc --version
/opt/rh/gcc-toolset-15/root/usr/bin/g++ --version
cmake --version
/home/eda/.local/xyce-tools/bin/flex --version
/home/eda/.local/xyce-tools/bin/bison --version
```

验收标准：

- `xyce_cc` 和 `xyce_cxx` 都指向 `/opt/rh/gcc-toolset-15/root/usr/bin`；
- SuiteSparse、Trilinos、Xyce 的 CMake cache 中编译器路径一致；
- 不复用 `/home/eda/.local/xyce-deps/install` 里由 GCC 8.5 构建的 Trilinos；
- 最小构建继续保持串行、Release、无 MPI、无 FFTW、无 ADMS、无测试构建。
