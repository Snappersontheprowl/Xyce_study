# Xyce Learning Outline

This document is the long-term study outline for reading the Xyce source code.

Current starting point:

- can read basic C++ syntax
- understands the broad purpose of a circuit simulator

The main goal of the first pass is not to understand every implementation detail.
The main goal is to build a reliable mental map:

- where the program starts
- how a netlist enters the system
- how a device becomes equations
- where the solver is invoked

## Study Strategy

Use this order:

1. Build a high-level map first.
2. Follow one simple end-to-end vertical slice.
3. Return to major subsystems with clearer context.
4. Only then fill in C++ and numerical details as needed.

This keeps the reading grounded in control flow and data flow instead of getting
stuck in isolated implementation details.

## Stage 1: Build the Overall Map

Goal:

- understand the major source directories and subsystem boundaries
- know which parts are startup, parsing, device modeling, analysis, and solving

Questions to answer:

- What are the major packages under `src/`?
- Which package appears to own top-level orchestration?
- Which packages look device-related, parser-related, or solver-related?

Suggested output:

- one page of package-level notes
- a short list of important classes and files

## Stage 2: Read Program Startup Flow

Goal:

- understand what happens from process start to the point where simulation work begins

Questions to answer:

- Where is `main()`?
- How are command-line arguments handled?
- Where are global options and runtime objects initialized?
- At what point does netlist loading begin?

Suggested output:

- a startup sequence such as `main -> setup -> parse -> build -> analyze`
- file paths for each major step

## Stage 3: Read Netlist Parsing and Circuit Construction

Goal:

- understand how text input becomes internal circuit data structures

Questions to answer:

- Where is the netlist parser entry?
- How are device lines and control statements separated?
- Where are nodes, devices, and models created or registered?
- What internal objects represent the parsed circuit?

Suggested output:

- a diagram from netlist text to in-memory circuit objects
- a short list of the core parsing and setup data structures

## Stage 4: Trace One Simple Device End-to-End

Goal:

- complete one full vertical slice from parse to matrix contribution

Recommended first device:

- resistor

Questions to answer:

- Which code parses a resistor instance?
- Where is the device object created?
- Where are its parameters stored?
- Which function performs its load or stamp behavior?
- How does it affect matrix entries or the right-hand side?

Suggested output:

- one trace note that follows `parse -> instantiate -> setup -> load`

## Stage 5: Read Analysis Flow

Goal:

- understand how Xyce organizes different analysis modes

Questions to answer:

- Where are `.OP`, `.DC`, and `.TRAN` handled?
- What part of the code dispatches the analysis type?
- What common infrastructure is reused across analyses?
- How do operating point solve and transient stepping relate?

Suggested output:

- a comparison note for major analysis types
- a short time-step or iteration flow for transient analysis

## Stage 6: Read Matrix Assembly and Solver Interface

Goal:

- understand how device equations are assembled and handed to solvers

Questions to answer:

- Where is the matrix abstraction defined?
- Do devices write directly into matrix structures or through helper layers?
- Where is the nonlinear solve loop organized?
- Where are linear solver calls made?

Suggested output:

- one path diagram from device load functions to solver calls
- a list of key assembly and solve interfaces

## Stage 7: Fill in the C++ Patterns That Matter

Goal:

- learn only the C++ mechanisms required to read this code productively

Focus topics:

- inheritance and abstract interfaces
- factory or registration mechanisms
- ownership through pointers and references
- package and header organization
- template usage only when it directly blocks understanding

Suggested output:

- a short note mapping each important C++ pattern to one real Xyce example

## Stage 8: Build, Test, and Modify Safely

Goal:

- move from passive reading to controlled experiments

Questions to answer:

- What is the smallest build path needed locally?
- Where are tests or validation examples located?
- If one device behavior changes, how should it be checked?
- What is the smallest safe debug edit for tracing flow?

Suggested output:

- a local workflow note for build, run, and verify

## Recommended Reading Order

For the current background, use this order:

1. overall source tree and package map
2. startup and top-level flow
3. netlist parser entry and circuit setup
4. resistor end-to-end trace
5. analysis flow for `.DC` and `.TRAN`
6. matrix assembly and solver interface
7. C++ patterns encountered in the above code
8. build, test, and controlled code experiments

## Reading Checklist for Each File

When reading a new file or class, focus on four questions:

1. Who creates this object?
2. What important data does it hold?
3. Who calls it, and at what stage?
4. What effect does it have on later simulation flow?

If implementation details get heavy, answer these four questions first before
digging deeper.

## What Not to Do in the First Pass

Avoid these traps early on:

- trying to understand every class before tracing real flow
- starting with the most complex device models
- diving into solver internals before locating the call path
- reading every option and corner feature before the core path is clear

## Suggested First-Week Goal

A strong first milestone is:

1. find the executable entry and top-level startup flow
2. find the netlist parsing entry
3. trace one simple device from parse to load or stamp

If these three are clear, the rest of the codebase becomes much easier to
navigate.

## Suggested Notes to Create

As reading progresses, create notes such as:

- `notes/YYYY-MM-DD-entry-flow.md`
- `notes/YYYY-MM-DD-parser-trace.md`
- `notes/YYYY-MM-DD-device-resistor.md`
- `notes/YYYY-MM-DD-analysis-flow.md`

Keep each note focused on:

- files read
- questions asked
- conclusions reached
- next trace targets
