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
