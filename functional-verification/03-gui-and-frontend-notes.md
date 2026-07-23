# Xyce GUI / 前端集成说明

## 结论

当前 Xyce 本体没有官方内置 GUI。它主要是命令行仿真后端：

```text
netlist -> Xyce -> text/probe/tecplot/noise 等输出文件
```

因此不能把当前安装理解为类似 LTspice、Qucs-S 或 Cadence ADE 那样的一体化图形环境。

同理，当前 Xyce 本体也没有类似 Spectre interactive mode 的交互式仿真 shell。它的基本运行模型仍是：

```text
准备 netlist -> 调用 Xyce -> 仿真完成 -> 写出结果文件 -> 进程退出
```

## 本地源码中的证据

当前源码树中没有 Xyce 自带 schematic capture 或完整 waveform GUI。可见的是若干辅助脚本，例如：

```text
vendor/Xyce-7.10.0/utils/plotXyce.py
vendor/Xyce-7.10.0/utils/gnuplotXyce.py
```

这些脚本用于快速绘制 Xyce 输出文件，不是完整电路图编辑器，也不是完整 GUI 仿真环境。

`plotXyce.py` 说明其用途是：

```text
quickly plot and/or animate Xyce output files
```

`gnuplotXyce.py` 说明其用途是：

```text
quickly plot and/or animate Xyce output files via gnuplot
```

## 官方/外部资料口径

Sandia Xyce 文档页面说明：Xyce 是 simulator，不自带 schematic capture interface；可与外部 schematic capture tools 搭配使用。

早期 Sandia 应用笔记也明确说明：Xyce 开发重点是 simulation engine，不包含 schematic capture tool 或 graphical display software。

Xyce 官方 GitHub README 把 Xyce 描述为 SPICE-compatible high-performance analog circuit simulator，支持 DC、transient、AC、noise、harmonic balance、sensitivity、UQ 等分析能力，但没有把 interactive command shell 作为运行方式列出。

当前本地安装的 `Xyce -h` 也只列出 batch/command-line 选项，例如：

```text
-syntax
-norun
-count
-remeasure
-param
-doc
-o
-l
-r
-plugin
```

没有发现类似 Spectre `interactive` / `control mode` / REPL / server shell 的入口。

## 与 Spectre interactive mode 的差异

Spectre interactive mode 常见用途是：

```text
启动仿真会话
在会话中执行 command
查询/保存结果
有时可配合 ADE/OCEAN/脚本做更交互式的分析控制
```

当前 Xyce 更适合的方式是：

```text
shell/Python/Jupyter 生成 netlist
调用 Xyce 命令行
读取 .prn/.csd/.raw/.dat 等输出
再由外部脚本做 sweep、优化、绘图或回归验证
```

也就是说，Xyce 的“交互性”通常不在 Xyce 进程内部，而在外层工作流中实现。

可替代方案：

1. 对参数扫描：使用 `.STEP`、`.DC`、`.TRAN`、`.AC` 或外部脚本生成多份 netlist；
2. 对结果查询：使用 `.PRINT`、`.MEASURE`、`-remeasure`；
3. 对流程控制：使用 Python/shell/Jupyter 调用 Xyce；
4. 对 GUI 操作：使用 Qucs-S、Xschem、gEDA、Revolution EDA 等前端；
5. 对波形查看：使用 Python、gnuplot、Qucs-S 或其它 waveform viewer。

## 可搭配的外部 GUI / 前端

常见可选路线：

1. Qucs-S
   - Qt 图形界面；
   - 可把 Xyce 作为外部 SPICE-compatible backend；
   - 适合教学、小电路、图形化 schematic + 仿真。

2. Xschem
   - 开源 schematic editor；
   - 可配置调用 Xyce；
   - 常见于开源 IC/PDK 流程，可配合 waveform viewer 使用。

3. gEDA / gschem
   - Sandia 曾提供过使用 gEDA 生成 Xyce netlist 的应用笔记；
   - 更偏传统开源 EDA 工具链。

4. 商业或半商业前端
   - 例如 Revolution EDA、Typhoon HIL schematic/editor integration 等；
   - 属于外部工具调用 Xyce，不是 Xyce 本体 GUI。

5. 波形查看
   - Xyce 自带输出文本、probe、tecplot、noise data 等；
   - 可用 Python、gnuplot、Qucs-S、GTKWave/自定义脚本、Jupyter 等方式可视化；
   - 当前项目已生成 `.prn`、`.FD.prn`、`.NOISE.prn`、`_noise.dat` 等结果文件，适合后续接入 Python/Jupyter 绘图。

## 对当前项目的建议

当前阶段仍建议保持：

```text
手写小 netlist + 命令行 Xyce + Python/Jupyter/gnuplot 后处理
```

原因：

- 更利于学习 Xyce 解析、分析器、器件模型和求解器内部机制；
- netlist 与输出文件可直接纳入 git；
- functional-verification 用例更容易自动化；
- 不会把 GUI 前端的 netlist 生成差异误判为 Xyce 本体问题。

当后续目标转向“画图建电路、快速看波形”时，再引入 Qucs-S 或 Xschem 作为前端更合适。

## 当前判断

当前 Xyce 安装：

```text
自带 GUI: no
Spectre-like interactive shell: no
自带轻量绘图脚本: yes
可被外部 GUI 调用: yes
建议当前学习阶段使用 GUI: not yet
```
