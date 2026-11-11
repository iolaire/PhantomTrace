---
inclusion: always
---

# Safety

PhantomTrace sends signals to processes and unmounts volumes on a user's real machine, and it parses untrusted data (file names). Treat every rule here as a hard constraint. Spec references: Requirements 2, 6, 9, 10, 14, 15.

## Single choke point

- `SafetyPolicy.evaluate` is the only approval path for every `ProposedAction`. Signal, quit, shell-egress, and unmount adapters are reachable only through `ResolutionPipeline` after an approval. UI and CLI never call adapters directly.
- Unknown or undeterminable state (owner, protection status, attempt history, 1000 ms) means **deny**.

## Never touch

- Protected processes are never sent a signal at any stage: PID 0, PID 1, PhantomTrace's own PID, `launchd`, `kernel_task`, `WindowServer`, `loginwindow`, `Finder`.
- Protected volumes are never scanned or mutated: `/`, anything under `/System/Volumes`, `/private/var/vm`. Unverifiable paths are treated as protected.
- Processes owned by other users are read-only and excluded from every stage unless the user explicitly initiates authorization. No silent privilege escalation.

## Escalation rules

- Stages are opt-in: only the stage the user explicitly selected runs, and only after the plan (actions and skipped locks with denial reasons) has been shown.
- Each stage plans from a **fresh** scan and finishes with a rescan (500 ms settle). Never reuse locks from an earlier scan.
- `SIGKILL` requires a recorded prior `quitApplication`/`SIGTERM` for the same `Process_Identity`, except a user-confirmed `systemDaemon`. Banish Locks lists name and pid and needs explicit confirmation.
- Before sending any signal, compare `(pid, process start time)` with the discovery-time identity; on mismatch skip and record `processIdentityChanged`.
- Unmount only after a fresh scan reports zero locks and the user confirmed. Non-forced by default; force only through the advanced confirmation. `kDAReturnBusy`/`EBUSY` goes back to Blocked and rescans.
- `EPERM` records `permissionDenied(pid:)`, fails that action, and continues.

## Untrusted data and subprocesses

- Launch subprocesses with `Process`, an absolute executable path, and an argument array. Never `/bin/sh -c`, never string-built commands.
- `lsof` paths, process names, and URL parameters are inert data: never executed, evaluated, or used as format strings. Pass paths after `--` or as absolute paths so a leading `-` cannot be an option.
- Every subprocess has a timeout (default 10 s; `lsof` 15 s; pre-unmount scan 10 s; stage scans 30 s). On timeout terminate it, discard partial output, report which command timed out, stay responsive.
- Text injected into a terminal is the fixed literal ` cd ~\n` and nothing derived from process data, paths, or user input.
- Validate `phantomtrace://` URLs: percent-decode, canonicalize (symlinks, `.`/`..`), reject empty, malformed, over 1024 characters, or nonexistent paths, and run no scan on rejection.
- `LsofParser` is total: it never traps or throws on any bytes. No force unwraps, `try!`, `fatalError`, or unchecked indexing in parsing paths.

## Privacy and network

- Zero network connections (inbound or outbound) and zero telemetry, analytics, or crash reporting. Do not add networking APIs, URLSession, or analytics SDKs.
- Diagnostic data stays on the machine; logs avoid full file paths at default level (use `OSLog` privacy `.private` for paths).

## Testing destructive code

- Tests and development never signal real processes or unmount real volumes except in the explicit local-only integration test using a temporary disk image and helper processes the test itself spawned.
- When manually testing, use a throwaway `.dmg`, never a real backup drive.
