# Xyce Source Study

This repository is a personal study workspace for reading the Xyce source code.

The goal is not to maintain a fork of Xyce. The goal is to keep source snapshots,
notes, reading plans, and helper scripts in one place with a clean structure.

## Repository Layout

- `vendor/Xyce-7.10.0/`: local unpacked Xyce source snapshot for reading
- `artifacts/source/`: downloaded release archives kept outside version control
- `docs/`: structured study notes and topic summaries
- `notes/`: dated reading notes, trace logs, and short findings
- `scripts/`: helper scripts for searching, building, or tracing the source

## Version Control Policy

- This repository tracks study materials, not the Xyce source tree itself.
- `vendor/Xyce-7.10.0/` is kept locally but ignored by Git.
- `artifacts/source/Release-7.10.0.tar.gz` is also kept locally but ignored by Git.

This keeps the study repository lightweight while preserving a stable local copy
of the exact source release being read.

## Official Sources

As checked on 2026-05-12:

- Official project site: https://xyce.sandia.gov/
- Official source download page: https://xyce.sandia.gov/downloads/source-code/
- Official GitHub repository: https://github.com/Xyce/Xyce

## Version Notes

- The GitHub default branch is `master`.
- The current release tag on GitHub is `Release-7.10.0`.
- The Sandia download page lists `Xyce-7.10.tar.gz` as the current source release.
- The local source directory is an extracted release snapshot, not a Git checkout.

If full upstream history is needed later, clone the official repository separately:

```bash
git clone https://github.com/Xyce/Xyce.git
```

## First Reading Targets

A practical first pass for source study:

1. Find the program entry and top-level driver flow.
2. Identify where netlists are parsed.
3. Trace a simple device such as a resistor.
4. Map where matrix assembly and solver calls happen.
