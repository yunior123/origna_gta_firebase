"""Module collect_files.py."""
from pathlib import Path

ALLOWED_EXTENSIONS = {
    ".py", ".js", ".ts", ".dart", ".yaml", ".yml", ".json", ".md",
    ".rules", ".sh",
}

EXCLUDE_DIRS = {
    ".git", "node_modules", "build", ".dart_tool", ".idea", ".vscode",
    "__pycache__", ".gradle", "android", "ios", "web", "macos", "linux",
    "windows", "audit", ".firebase", ".pub-cache", "venv", ".venv",
    "test-results", "playwright-report", "archive", "emulator-data",
}

EXCLUDE_FILES = {
    ".env", "serviceAccountKey.json", "credentials.json",
    "package-lock.json", "pubspec.lock", "firebase-debug.log",
}


def collect_project_files(root="."):
    """Function collect_project_files."""
    files = []
    for path in Path(root).rglob("*"):
        if any(part in EXCLUDE_DIRS for part in path.parts):
            continue
        if path.name in EXCLUDE_FILES:
            continue
        if path.suffix in ALLOWED_EXTENSIONS and path.is_file():
            files.append(path)
    return sorted(files)


def bundle_files(files, max_chars=120_000):
    """Bundle file contents into a single string, truncating to stay under token limits."""
    content = []
    total = 0

    for f in files:
        try:
            text = f.read_text(errors="ignore")
        except Exception:
            continue
        block = f"\n\n### FILE: {f}\n```\n{text}\n```"
        if total + len(block) > max_chars:
            content.append(f"\n\n[TRUNCATED — {len(files) - len(content)} files omitted due to size limit]")
            break
        content.append(block)
        total += len(block)

    return "".join(content)
