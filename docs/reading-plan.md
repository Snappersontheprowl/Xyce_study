# Reading Plan

## Current Focus

1. Find the executable entry path and top-level control flow.
2. Locate netlist parsing and circuit setup.
3. Trace one simple device from parse to stamping.
4. Identify where linear system assembly and solver calls happen.

## Working Notes

- Start from the top-level binary entry and follow constructor and initialization flow.
- Prefer one small vertical slice at a time instead of scanning every package.
- Record file paths and short conclusions in `notes/` as you go.
