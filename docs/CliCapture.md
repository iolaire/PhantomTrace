# CLI Capture: Demo Volume

Real output of the read-only `phantomtrace` CLI against a throwaway disk image, captured on 2026-11-13 (UTC) at commit `1d932e0`.

- Machine: macOS 27.2.1 (build 26B131), debug build (`swift build`, `.build/debug/phantomtrace`).
- Setup: a 10 MB APFS image named `PhantomDemo`, attached at `/Volumes/PhantomDemo`. Two helpers were started by the capture script: a `tail -f` on `notes.txt` (a held open file) and an interactive `zsh` whose working directory is the volume, with its input held open on a fifo (an idle shell).
- Cleanup: the helpers were stopped and the image detached and deleted afterwards. No real drive was used, and the CLI never signals a process or unmounts anything.
- Columns (tab separated): pid, process name, user, lock category, process role, path.

```
$ phantomtrace /Volumes/PhantomDemo
55691	tail	iolaire	openFileHandle	cliTool	/Volumes/PhantomDemo/notes.txt
55694	zsh	iolaire	cwd	idleShell	/Volumes/PhantomDemo
[exit code 0]

$ phantomtrace "phantomtrace://inspect?path=%2FVolumes%2FPhantomDemo"
55691	tail	iolaire	openFileHandle	cliTool	/Volumes/PhantomDemo/notes.txt
55694	zsh	iolaire	cwd	idleShell	/Volumes/PhantomDemo
[exit code 0]
```

What it shows:

- `tail` (pid 55691) holds `notes.txt` open: category `openFileHandle`, role `cliTool`.
- `zsh` (pid 55694) sits in the volume root: category `cwd`, role `idleShell`. This is the kind of lock the Egress Shells stage resets with `cd ~`.
- A plain path and a `phantomtrace://inspect?path=...` URL give the same result, and both exit 0.

Limits: this is the CLI only. It does not show the app windows, the Quick Action, or any resolution stage. Pids are specific to this run.

## The old way, same volume

The same two locks, tried with Finder and with the built-in tools. Captured 2026-11-13 on a fresh throwaway image with the same helpers. Finder's dialog is in [screenshots/finder-eject-fails.png](screenshots/finder-eject-fails.png): it says "one or more programs may be using it" and names none.

```
$ diskutil unmount /Volumes/PhantomDemo
Volume PhantomDemo on disk8s1 failed to unmount: dissented by PID 95849 (/usr/bin/tail)
Dissenter parent PPID 1 (/sbin/launchd)
[exit 1]

$ lsof +f -- /Volumes/PhantomDemo
COMMAND   PID    USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
tail    95849 iolaire    3r   REG   1,30        6   18 /Volumes/PhantomDemo/notes.txt
zsh     95851 iolaire  cwd    DIR   1,30      128    2 /Volumes/PhantomDemo
```

Honest comparison: `diskutil unmount` does name one blocker, but only the first it hits (`tail`, not the `zsh`). `lsof` lists both, but as raw output with no lock category, no process role, and no safe way to act. PhantomTrace's value is the complete list, the plain labels, and the previewed, opt-in steps.
