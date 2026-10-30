---
name: sdd-pair
description: Pair programming on an approved OpenSpec change. Implements ONE pending task of tasks.md in small test-driven steps (one test → red → minimum code → green) and stops to wait for my go-ahead. Never commits, never edits specs to match the code. Use instead of /opsx:apply.
disable-model-invocation: true
---

# SDD Pair

You are the driver: you write the code. I am the navigator: I review, decide and tell you yes or no. The specs and tasks of the OpenSpec change are the contract I already approved; your job is to implement them in steps small enough that I understand every line before we move on.

Generating code is cheap; understanding it is not. Stopping often is the point, not a limitation.

## 1. Load the change

1. Pick the change: use the name I give you; otherwise infer it from the conversation; otherwise auto-select if only one active change exists; otherwise run `openspec list --json` and ask me. Announce: `Using change: <name>`.
2. Run `openspec instructions apply --change "<name>" --json` (append `--store "<id>"` only if the change lives in a registered store).
   - `state: "blocked"`: show the message and stop. If `missingArtifacts` is non-empty, suggest `/opsx:propose` or `/opsx:continue` to finish planning.
   - `state: "all_done"`: say so and go to **6. Close the change**.
3. Read every file listed in `contextFiles` (impact, proposal, specs, design, tasks). Treat `context` as project facts and `operationGuidance` as advice; neither overrides this skill.
4. If the project uses a long-running test server (see **Running tests**), start it now, in the background, and carry on: it warms up while you prepare the task and the test list.

## 2. Pick ONE task

- Take the **first unchecked task**. Show it with progress: `Task 2.1 (4/9): <description>`.
- Check it against the current code. If the design or the task no longer fits, tell me before starting.
- A task may need several TDD cycles: its size follows the "Complejidad" level in design.md (bajo: few large tasks; alto: one scenario per task). You still stop after every cycle. If the task is clearly bigger than its level allows, propose splitting it into smaller checkbox tasks in tasks.md and wait for my approval before editing tasks.md.

## 3. Test list

- From the scenarios the task covers, propose **the test list: names only, don't write them yet.**
- Say **where** each one is tested (endpoint, service, component…). Prefer the highest practical level.
- Include the regression tests the task owes for rules listed in impact.md.
- Mark what can't be tested well (for example, visual behavior) as **manual verification**.
- Wait for my approval. I approve the list, not you.

## 4. Cycle

One step = one test from the list:

1. Write the test.
2. Run it and **show that it fails** (red), for the expected reason.
3. Write the **minimum code** that makes it pass. Nothing the test doesn't require.
4. Run the tests and show that they pass (green).

By default you do **1 step** and stop. If I say "do N", you do N full cycles (test → code → green, one after another), never "N tests and then the code". In a batch, list the test files first and then the code files: the tests are what I most need to review.

**Never paste code or tests into the conversation**: no code blocks, no diffs, no excerpts. I review them in my IDE. Tell me which files you wrote or changed, as `path:line` pointing to each test and each code change. For red and green, report only the outcome in one line (which test failed and why, or that it passed), not the full output.

When you stop, send a micro message:

```
PASS "<test name>". <what I did in one line>
Files: <test file:line>, <code file:line>
Decided: <judgment call not in design.md, if any — otherwise omit>
Change anything or continue with "<next test>"?
```

### Stop immediately (even mid-batch) if:

- You need a design decision that isn't in design.md.
- You think of adding something the specs don't ask for, even if it seems reasonable.
- Making a test pass would require changing, skipping or deleting a test.
- You've had two attempts without reaching green.
- The step exceeds ~50 lines or touches more than 3 files: propose splitting it.
- The code you're asked to write contradicts an approved spec, or an approved spec looks wrong.

### Running tests

Use the project's own test commands. Before the first test run of the session, read `package.json`.

**Angular projects (IMPERATIVE).** If the project is Angular (`angular.json` exists or `@angular/core` is a dependency) **and** `package.json` declares both the `test:server` and `karma:run` scripts, you MUST run tests this way and no other (never `ng test`, `npm test` or a direct Karma call):

1. **Start the test server once, in the background, and leave it running for the whole session.** `npm run test:server` never returns: running it in the foreground, or waiting for it to finish, blocks the session. **Never wait for its return.**
   - **Start it early** (when you load the change) and keep working: read the artifacts, propose the test list, wait for my approval. Don't sit idle while it builds.
   - **Check readiness only right before the first `karma:run`.** On start-up `ng test` builds the bundles and then runs the whole suite once; it is ready when the log shows that first run finished (a line like `Executed N of N` or `TOTAL:`). Compile errors in the log mean it is not ready: report them.
   - If it isn't ready yet, poll the log with short waits (about 10 s each), never long sleeps. If it still isn't ready after about 5 minutes, stop and tell me what the log shows.
   - The results of that initial full-suite run are not the result of your test: only `karma:run` output counts.
2. **Run only the tests you need, by description**, where `<description>` is the `describe`/`it` text of the test(s). To run several related tests, pass the description of their enclosing `describe`.
3. **Read the result from the `karma:run` output** (passed/failed tests and errors), not from the server's output. Red and green are both shown with this command.

Use the commands for the shell you are running in:

**PowerShell (Windows)**

```powershell
# 1. Already running? If this prints anything, don't start another one.
Get-CimInstance Win32_Process -Filter "Name='node.exe'" | Where-Object { $_.CommandLine -match 'test:server' }

# 1. Start it detached (returns immediately; survives the end of this PowerShell session)
Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "npm run test:server > .test-server.log 2>&1" -WindowStyle Hidden

# 1. Ready? Only right before the first karma:run. Short waits, never long sleeps.
#    Ready when the initial run finished: "Executed N of N" or "TOTAL:"
Start-Sleep -Seconds 10; Get-Content .test-server.log -Tail 30

# 2-3. Run the tests by description and read this output. Use npm.cmd, not npm:
#      the npm.ps1 shim can swallow the "--" and the description never reaches karma:run.
npm.cmd run karma:run -- "libera recursos al cancelar"
```

Don't use `Start-Job` or `&`-backgrounding for the server: a job dies when the PowerShell session that created it ends.

**bash / zsh (Linux, macOS, Git Bash, WSL)**

```bash
pgrep -f "test:server"                                   # already running?
nohup npm run test:server > .test-server.log 2>&1 &      # start detached
sleep 10; tail -n 30 .test-server.log                    # ready? ("Executed N of N" / "TOTAL:")
npm run karma:run -- "libera recursos al cancelar"       # run by description
```

If your tool has its own background mode for long-running commands (for example, Claude Code's Bash `run_in_background`), you may use it instead of the detached launch above.

In every shell: never stop the server and never start a second one. If it crashes (the log shows it exited, or `karma:run` can't connect), start it again the same way.

If either script is missing, use the project's usual test command instead.

### Test rules

- The expected value comes from the spec scenario, **never computed with the same logic as the code**.
- Test behavior through the public interface, not internal details.

### Complexity rule

Every function or method you write or touch must have a **cognitive complexity of 15 or less** (SonarSource definition) whenever possible.

- Measure it with the project's linter or analyzer when one is configured (SonarQube/SonarLint, `sonarjs/cognitive-complexity`, PMD `CognitiveComplexity`, `complexipy`…). Otherwise estimate it with the SonarSource rules and say it's an estimate.
- Keep the "minimum code" simple from the start: early returns and guard clauses over nested conditionals, small named helpers over long branches.
- If a function ends up above 15 after green, don't move on to the next test: report it in the micro message (`Complexity: <function> = <n> > 15`) and propose the refactor that brings it down. The refactor is its own step, with tests green and no new functionality.
- A function may stay above 15 only with my explicit approval and a stated reason (for example, a flat mapping that reads worse when split).
- If touching existing code above 15 is required, mention it, but don't refactor it beyond what the task needs unless I ask.

### Spec rules

- Approved specs (`openspec/specs/` and this change's delta specs) are the contract. **Never edit a spec so it matches what the code does.**
- If a spec seems wrong or incomplete, stop and propose the exact spec change to me. I decide; then it's updated as a planning change (`/opsx:update`), not as a side effect of coding.

## 5. Finish the task

When every test of the task is green:

1. Mark the task done at the `sourcePath` and `line` returned by the apply instructions: `- [ ]` → `- [x]`. First confirm that line still matches the task; if not, rerun the instructions. Only mark it when its specified behavior is fully implemented.
2. Rerun `openspec instructions apply --change "<name>" --json` and confirm progress changed.
3. Verify together any **manual verification** items of the task.
4. If something repeats or looks messy, **suggest** the refactor in words, pointing to `path:line`; I decide. Refactor only with tests green and never mixed with new functionality.
5. If we made a decision that applies to the whole project, propose a line for `AGENTS.md` / `CLAUDE.md`.
6. **Never commit.** Tell me it's a good commit point and suggest the message, separating functionality and refactor into different commits. I make the commit.
7. Stop. Ask whether to continue with the next task (`/sdd-pair` again, or "continue").

## 6. Close the change

When all tasks are done:

- Suggest a review with a clean context (`/code-review` or equivalent); don't review your own code.
- Suggest `/opsx:verify` to check implementation against the specs, then `/opsx:archive` to merge the delta specs into `openspec/specs/`.

## Never

- Implement more than one task per run without my explicit go-ahead.
- Invent requirements, or fill gaps with assumptions: ask.
- Add abstractions, layers, configuration or patterns "for the future".
- Commit, push, or edit specs to justify the code.
