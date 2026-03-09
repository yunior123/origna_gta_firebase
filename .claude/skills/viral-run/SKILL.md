---
name: viral-run
description: Use when running the viral-video-pipeline — full pipeline or a specific stage (ideation, generation, postprocess, upload). Always cd to the project dir first.
disable-model-invocation: true
---

# /viral-run Skill

Runs `viral-video-pipeline` stages using `uv run python3`.

## Project

```
~/Documents/GitHub/viral-video-pipeline
```

Runtime: `uv run python3` (reads `pyproject.toml` — do NOT use bare `python3`).

## Available Stages

| Stage | Command |
|-------|---------|
| `full` (no arg) | `uv run python3 -m src` |
| `ideation` | `uv run python3 -m src.ideation` |
| `generation` | `uv run python3 -m src.generation` |
| `postprocess` | `uv run python3 -m src.postprocess` |
| `upload` | `uv run python3 -m src.upload` |

## Usage

```bash
# Full pipeline
cd ~/Documents/GitHub/viral-video-pipeline && uv run python3 -m src

# Single stage
cd ~/Documents/GitHub/viral-video-pipeline && uv run python3 -m src.<stage>
```

## On Failure

- Show `stderr` output in full — do not truncate.
- Check for missing `.env` values or missing API keys first.
- Rerun with `--dry-run` if supported to isolate the failing stage.

## Rules

- Always `cd` to project dir before running.
- Never use bare `python3` — always `uv run python3`.
- Never run `full` without confirming API rate limits / cost with the user if running `generation` or `upload`.
