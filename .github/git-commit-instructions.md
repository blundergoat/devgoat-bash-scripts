# Git Commit Instructions

Use short imperative subjects. One script per commit, or one coherent workflow when changes span related files.

```
add docker restart wrapper
fix aws-costs empty output crash
rename start.sh to start-dev.sh
```

Never commit credentials, `.env` files, or generated code. After renames, grep for the old name across the entire codebase and update all references before committing.

See `ai/instructions/git-commit.md` for full details.
