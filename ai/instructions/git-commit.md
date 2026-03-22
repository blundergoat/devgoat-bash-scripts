# Git Commit Format — devgoat-bash-scripts

## Message Format

Use short imperative subjects:

```
add docker restart wrapper
fix aws-costs empty output crash
rename start.sh to start-dev.sh
```

## Scope Rules

- **One script per commit** when the change is isolated to a single file
- **One coherent workflow per commit** when changes span multiple related files (e.g., a new script plus its test)
- Never bundle unrelated changes

## What Not to Commit

- Credentials, tokens, or `.env` files
- Generated code or lockfiles (unless intentional)
- Changes to CONFIGURATION block default values (those are user-specific)

## After Renames

When renaming a file, grep for the old name across the entire codebase and update all references before committing. This includes: README.md, CHANGELOG.md, help.sh, docs/code-map.md, and any scripts that source or reference the renamed file.
