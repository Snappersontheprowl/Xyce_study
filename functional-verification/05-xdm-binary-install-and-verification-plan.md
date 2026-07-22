# XDM 二进制安装与最小验证计划

## 1. 目标

本计划只采用 XDM 官方二进制安装方式，不进行源码构建。

目标是：

1. 在项目目录下安装 XDM，不污染系统路径；
2. 确认 `xdm_bdl` 可以启动；
3. 用最小 HSPICE-like 网表验证转换链路；
4. 用当前已安装的 Xyce 验证转换后网表可解析、可运行。

## 2. 事实依据

Xyce 官方 executables 页面为 RHEL8 提供 Xyce XDM 二进制包，并说明 XDM binary installation 参考 XDM User Guide。

XDM User Guide 2.7 说明：

- XDM 支持将 PSpice、HSPICE、Spectre 网表转换为 Xyce 网表；
- Sandia 提供带有 Boost 和 Python3 依赖的二进制包；
- Linux 版本以 zip 形式交付，例如 `xdm-2.7.0-Linux.zip`；
- Linux/OS X 安装步骤是 unzip，然后把解压目录移动到目标位置；
- `xdm_bdl` 是命令行 standalone executable；
- 可把 XDM 的 `bin` 目录加入 `PATH`。

因此，本项目优先采用 binary-first 路线。

## 3. 推荐安装位置

为了不影响系统环境，建议把 XDM 放在项目目录内：

```text
artifacts/tools/xdm-2.7.0-Linux.zip
out/tools/xdm-2.7.0-Linux/
functional-verification/cases/fv009-xdm-hspice-minimal/
```

这样做的好处：

- 不需要 `sudo`；
- 不写入 `/usr/local`；
- 不影响已经完成的 Xyce 主安装；
- 后续删除或升级 XDM 很容易；
- 验证记录可以和本项目一起管理。

## 4. 下载二进制包

从项目根目录执行：

```bash
cd /home/eda/my_lab/projects/study/xyce_study

mkdir -p artifacts/tools out/tools build/logs

curl -L \
  -o artifacts/tools/xdm-2.7.0-Linux.zip \
  https://xyce.sandia.gov/files/xyce/Binaries/xdm-2.7.0-Linux.zip

sha256sum artifacts/tools/xdm-2.7.0-Linux.zip
```

如果 `curl` 因网络/TLS 问题失败，可改用：

```bash
wget --no-check-certificate \
  https://xyce.sandia.gov/files/xyce/Binaries/xdm-2.7.0-Linux.zip \
  -O artifacts/tools/xdm-2.7.0-Linux.zip

sha256sum artifacts/tools/xdm-2.7.0-Linux.zip
```

记录 `sha256sum`，便于后续复现。

## 5. 解压安装

```bash
cd /home/eda/my_lab/projects/study/xyce_study

unzip -q artifacts/tools/xdm-2.7.0-Linux.zip -d out/tools

find out/tools -maxdepth 3 -type f -name 'xdm_bdl' -print
```

期望至少找到类似：

```text
out/tools/xdm-2.7.0-Linux/bin/xdm_bdl
```

若 zip 内目录名略有不同，以 `find` 结果为准。

## 6. 本次 shell 临时启用 XDM

```bash
cd /home/eda/my_lab/projects/study/xyce_study

xyce_xdm_bin="$(find "$PWD/out/tools" -maxdepth 4 -type f -path '*/bin/xdm_bdl' | sort | head -n 1)"
test -x "$xyce_xdm_bin" && echo "XDM exists: $xyce_xdm_bin"

export PATH="$(dirname "$xyce_xdm_bin"):$PATH"

xdm_bdl -h | head -n 40
```

如果输出 usage/help 信息，说明 XDM 基本可启动。

不建议一开始把它永久写入 `.bashrc`。先完成最小验证，再决定是否加入长期 PATH。

## 7. 动态库检查

虽然 XDM User Guide 说明 binary 自带 Boost/Python3 依赖，但仍建议检查：

```bash
ldd "$xyce_xdm_bin" | tee build/logs/xdm-ldd.log

rg -n 'not found|boost|python|libstdc\+\+|glibc|GLIBC' build/logs/xdm-ldd.log
```

判断规则：

- 若出现 `not found`：说明 binary 与当前系统不完全匹配，需要处理运行库路径或换安装路线；
- 若无 `not found`：继续做功能验证；
- `boost/python` 出现不一定是问题，关键看是否能解析到有效路径。

## 8. FV-009：最小 HSPICE-like 网表转换验证

创建一个非常小的输入网表：

```bash
cd /home/eda/my_lab/projects/study/xyce_study

mkdir -p functional-verification/cases/fv009-xdm-hspice-minimal/input
mkdir -p functional-verification/cases/fv009-xdm-hspice-minimal/out

cat > functional-verification/cases/fv009-xdm-hspice-minimal/input/resistor-hspice.sp <<'EOF'
* FV-009 XDM HSPICE-like minimal resistor test
.option post
V1 1 0 DC 1
R1 1 0 1k
.op
.print dc V(1) I(V1)
.end
EOF
```

运行转换：

```bash
xdm_bdl \
  -s hspice \
  -d functional-verification/cases/fv009-xdm-hspice-minimal/out \
  -o xyce \
  --auto \
  functional-verification/cases/fv009-xdm-hspice-minimal/input/resistor-hspice.sp \
  2>&1 | tee build/logs/xdm-fv009-hspice-convert.log
```

检查转换日志：

```bash
rg -n "ERROR|Error|error|Traceback|WARNING|Warning|warning" \
  build/logs/xdm-fv009-hspice-convert.log || true
```

检查输出文件：

```bash
find functional-verification/cases/fv009-xdm-hspice-minimal/out -maxdepth 2 -type f -print -exec sed -n '1,80p' {} \;
```

## 9. 用当前 Xyce 验证转换结果

当前项目 Xyce 安装路径：

```bash
xyce_install="/home/eda/my_lab/projects/study/xyce_study/out/xyce-7.10-serial-release"
test -x "$xyce_install/bin/Xyce" && "$xyce_install/bin/Xyce" -v
```

找到转换后的网表：

```bash
xyce_xdm_out_netlist="$(find functional-verification/cases/fv009-xdm-hspice-minimal/out -type f \( -name '*.sp' -o -name '*.cir' -o -name '*.ckt' \) | sort | head -n 1)"
echo "$xyce_xdm_out_netlist"
```

先做语法检查：

```bash
"$xyce_install/bin/Xyce" -syntax "$xyce_xdm_out_netlist" \
  2>&1 | tee build/logs/xdm-fv009-xyce-syntax.log
```

再实际运行：

```bash
"$xyce_install/bin/Xyce" "$xyce_xdm_out_netlist" \
  2>&1 | tee build/logs/xdm-fv009-xyce-run.log
```

检查错误：

```bash
rg -n "Netlist error|MSG_FATAL|MSG_ERROR|Simulation aborted|Xyce Abort|failed|fatal|error|Traceback" \
  build/logs/xdm-fv009-xyce-syntax.log \
  build/logs/xdm-fv009-xyce-run.log || true
```

检查输出值：

```bash
find functional-verification/cases/fv009-xdm-hspice-minimal/out -type f \( -name '*.prn' -o -name '*.csd' \) -print -exec sed -n '1,80p' {} \;
```

预期数值仍应接近：

```text
V(1)  =  1.0
I(V1) = -1.0e-3
```

## 10. 通过标准

FV-009 通过条件：

1. `xdm_bdl -h` 能正常输出 help；
2. `ldd xdm_bdl` 没有 `not found`；
3. XDM 能生成输出网表；
4. XDM 转换日志中没有 fatal/error/traceback；
5. 当前 Xyce 对转换后网表 `-syntax` 通过；
6. 当前 Xyce 实跑成功；
7. 输出值满足最小电阻电路预期。

注：由于 XDM 会把 `.print dc` 转换为 `.PRINT DC FORMAT=PROBE ...`，Xyce 可能生成 `.csd` 结果文件，而不是 `.prn`。本用例中 `.csd` 是正常输出。

## 11. 暂不做的事情

本阶段不做：

- 不源码构建 XDM；
- 不安装到 `/usr/local`；
- 不修改系统级 `PATH`；
- 不碰真实 PDK；
- 不直接转换复杂 Spectre/HSPICE deck；
- 不把 XDM 结果当作“自动无损转换”的证据。

## 12. 后续扩展

FV-009 通过后，再依次增加：

```text
FV-010: XDM PSpice resistor/diode/RLC netlist -> Xyce
FV-011: XDM HSPICE MOS + .MODEL netlist -> Xyce
FV-012: XDM Spectre simple resistor/RC netlist -> Xyce
FV-013: XDM include/lib/section 最小验证
FV-014: XDM 转换真实模型卡前的语法覆盖检查
```

## 13. 参考资料

- Xyce executables page: https://xyce.sandia.gov/downloads/executables/
- XDM User Guide 2.7: https://xyce.sandia.gov/files/xyce/XDM_User_Guide_2.7.pdf
- XDM GitHub repository: https://github.com/Xyce/XDM
