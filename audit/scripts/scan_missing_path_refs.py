"""Scan tracked text files for references to missing repo paths.

Goal: catch stale references after files were moved/removed (scripts/docs/tests).

Heuristic-only: finds strings that look like repo-relative paths and checks if
they exist on disk.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
from dataclasses import dataclass


TEXT_EXTS = {
    ".ts",
    ".tsx",
    ".js",
    ".jsx",
    ".dart",
    ".py",
    ".sh",
    ".md",
    ".json",
    ".yaml",
    ".yml",
    ".toml",
    ".txt",
    ".xml",
    ".html",
    ".css",
    ".scss",
    ".env",
    ".gitignore",
}


@dataclass(frozen=True)
class MissingRef:
    """Class MissingRef."""
    raw: str
    repo_rel: str
    locations: tuple[tuple[str, int], ...]


def _is_text_file(path: str) -> bool:
    base = os.path.basename(path)
    _, ext = os.path.splitext(path)
    return ext in TEXT_EXTS or base in {"Makefile", "Dockerfile"}


def _git_ls_files(repo_root: str) -> list[str]:
    return (
        subprocess.check_output(["git", "ls-files"], cwd=repo_root, text=True)
        .splitlines()
    )


def _scan_file(
    repo_root: str,
    rel_path: str,
    *,
    path_re: re.Pattern[str],
    abs_re: re.Pattern[str],
) -> list[tuple[str, int, str, str]]:
    full = os.path.join(repo_root, rel_path)
    out: list[tuple[str, int, str, str]] = []
    try:
        with open(full, "r", encoding="utf-8", errors="ignore") as f:
            for line_no, line in enumerate(f, 1):
                for m in path_re.finditer(line):
                    raw = m.group("p").rstrip(").,;:")
                    # Ignore globs/patterns and multi-path strings.
                    if any(ch in raw for ch in ("*", "?", "[", "]", "{", "}", ",")):
                        continue
                    if any(ch in raw for ch in ("$", "{", "}")):
                        continue
                    repo_rel = raw[2:] if raw.startswith("./") else raw
                    # Ignore extension-less refs (common TS/Dart imports like './api-helpers').
                    if not repo_rel.endswith("/") and os.path.splitext(repo_rel)[1] == "":
                        continue
                    out.append((rel_path, line_no, raw, repo_rel))

                for m in abs_re.finditer(line):
                    p = m.group("p").rstrip(").,;:")
                    if any(ch in p for ch in ("*", "?", "[", "]", "{", "}", ",")):
                        continue
                    if any(ch in p for ch in ("$", "{", "}")):
                        continue
                    out.append((rel_path, line_no, f"{repo_root}/{p}", p))
    except OSError:
        return []
    return out


def find_missing_refs(repo_root: str, *, max_results: int) -> list[MissingRef]:
    """Function find_missing_refs."""
    tracked = _git_ls_files(repo_root)

    # Match ./foo, scripts/foo, e2e/foo, or common repo-root folders.
    path_re = re.compile(
        r"(?P<q>['\"`])(?P<p>(?:\./|scripts/|e2e/|functions/|origna_gta/|docs/)[^'\"`\s]+)(?P=q)"
    )
    abs_re = re.compile(re.escape(repo_root) + r"/(?P<p>[^\s'\"`]+)")

    candidates: list[tuple[str, int, str, str]] = []
    for rel in tracked:
        if not _is_text_file(rel):
            continue
        candidates.extend(_scan_file(repo_root, rel, path_re=path_re, abs_re=abs_re))

    missing: dict[tuple[str, str], list[tuple[str, int]]] = {}
    for file_rel, line_no, raw, repo_rel in candidates:
        if repo_rel.endswith("/"):
            continue
        fullp = os.path.join(repo_root, repo_rel)
        if not os.path.exists(fullp):
            missing.setdefault((raw, repo_rel), []).append((file_rel, line_no))

    items = sorted(missing.items(), key=lambda kv: (-len(kv[1]), kv[0][1]))
    refs: list[MissingRef] = []
    for (raw, repo_rel), locs in items[:max_results]:
        refs.append(MissingRef(raw=raw, repo_rel=repo_rel, locations=tuple(locs)))
    return refs


def main() -> int:
    """Function main."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", default=os.getcwd())
    parser.add_argument("--max", type=int, default=120)
    args = parser.parse_args()

    repo_root = os.path.abspath(args.repo)
    refs = find_missing_refs(repo_root, max_results=args.max)

    tracked = _git_ls_files(repo_root)
    scanned = sum(1 for r in tracked if _is_text_file(r))

    print(f"Repo: {repo_root}")
    print(f"Scanned tracked text files: {scanned}")
    print(f"Missing path refs found: {len(refs)}")
    print("---")
    for ref in refs:
        sample = "; ".join([f"{f}:{ln}" for f, ln in ref.locations[:6]])
        extra = "" if len(ref.locations) <= 6 else f" (+{len(ref.locations) - 6} more)"
        print(f"{len(ref.locations):>3}x  {ref.raw}  ->  {ref.repo_rel}  ::  {sample}{extra}")

    return 1 if refs else 0


if __name__ == "__main__":
    raise SystemExit(main())
