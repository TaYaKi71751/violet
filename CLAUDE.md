# Claude Code Rules for violet-project

## Git Commit Rules

### CRITICAL: NEVER use `git add -A` or `git add .`

**FORBIDDEN COMMANDS:**
- `git add -A`
- `git add .`
- `git add --all`

**REQUIRED BEHAVIOR:**
- ALWAYS add files individually by specifying exact file paths
- ALWAYS verify what files are being staged before committing
- NEVER stage more than 10 files without explicit user confirmation

**Example of CORRECT usage:**
```bash
git add violet-web/packages/frontend/src/hooks/useLocalSearchState.ts
git add violet-web/packages/frontend/src/pages/BookmarksPage.tsx
```

**Example of FORBIDDEN usage:**
```bash
git add -A  # ❌ NEVER DO THIS
git add .   # ❌ NEVER DO THIS
```

### Before Creating Any Commit

1. Run `git status` to see what will be committed
2. Review the file list carefully
3. Only add specific source files that are relevant to the change
4. NEVER add:
   - Build artifacts (target/, dist/, build/, node_modules/)
   - Cache files (__pycache__/, *.pyc)
   - Lock files (Cargo.lock, package-lock.json) unless explicitly requested
   - IDE files (.vscode/, .idea/)
   - Large binary files (*.zip, *.pkl, *.bin)

### If User Asks to Create a Commit

1. Ask which specific files should be included
2. Stage only those files individually
3. Show the staged files for confirmation
4. Only then create the commit

## Enforcement

If the agent violates these rules, the user will be very upset. These rules exist because a previous incident caused 3600+ unwanted files to be committed.
