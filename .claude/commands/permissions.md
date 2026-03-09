# /permissions - Set safe permissions without repeating

**Usage**: `/permissions`

## What it does:
Automatically grants safe permissions for common operations:
- ✅ Read/write project files
- ✅ Run tests
- ✅ Git operations (commit, push)
- ✅ Install dependencies (npm, pip, flutter)
- ✅ Build and deploy
- ❌ System-wide changes
- ❌ Delete important files (.git, node_modules, etc.)

## Pre-approved Operations:
```yaml
safe_operations:
  file_operations:
    - read: "**/*"
    - write: "**/*.{py,dart,js,md,json,yaml}"
    - create: "**/*.{py,dart,js,md,json}"
    - delete: "**/*.pyc,**/.DS_Store,**/node_modules"
  
  commands:
    - "git add ."
    - "git commit -m *"
    - "git push"
    - "pytest *"
    - "flutter test *"
    - "flutter build *"
    - "firebase deploy"
    - "npm install *"
    - "pip install *"
  
  restricted:
    - "rm -rf /"
    - "rm -rf .git"
    - "sudo *"
    - "chmod 777 *"
```

## Implementation:
This command documents pre-approved operations. Claude should:
1. Check operation against safe list
2. Proceed if safe
3. Ask confirmation if potentially dangerous
4. Never execute restricted operations

## Usage in prompts:
```
"Using /permissions, please update all test files and commit changes"
```
