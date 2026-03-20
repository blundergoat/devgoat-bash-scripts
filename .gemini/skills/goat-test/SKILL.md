# /goat-test — Testing and Verification Instructions

Generate comprehensive testing instructions after a milestone or coding session.

## Instructions

### MUST (cannot skip)
1. **Identify the changed code paths** and associated tests.
2. **Determine the "Doer-Verifier" principle:** How will someone else verify your work?
3. **Produce three categories of testing:**

### Category 1: Automated Test Commands
- Exact commands for the agent to run (`bats tests/`, `shellcheck`, `bash -n`).
- Expected output for success.

### Category 2: AI Verification Prompts
- Prompts for a *separate* agent to verify behavior.
- Example: "Check if `lib/aws/s3-sync.sh` correctly handles spaces in filenames by running..."

### Category 3: Manual Testing Steps
- Step-by-step instructions for a human.
- Example: "1. Run the script with --dry-run. 2. Verify the following output..."

## Output Format
```md
## Testing Instructions

### Automated
[Command 1]
[Command 2]

### AI Verification
[Prompt 1]

### Manual
1. [Step 1]
2. [Step 2]
```
