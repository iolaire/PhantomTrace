### PhantomTrace: Volume Lock Forensics & Banishment

**Elevator Pitch:** A retro-themed macOS contextual forensic utility that demystifies Finder’s opaque *"The disk wasn't ejected because one or more programs may be using it"* dialog by pinpointing the exact locking processes and open file handles, allowing users to safely resolve blockers and unmount external drives.

---

#### 1. Core Problem & Practical Impact

When external drives, USB sticks, or disk images (`.dmg`) fail to unmount on macOS, Finder displays a generic error dialog without identifying the responsible application. Users are typically forced to resort to manual terminal commands (`lsof`, `fuser`, `kill -9`) or pull the physical cable at the risk of filesystem corruption.

**PhantomTrace** gives users instant visibility into the mount blocker, differentiating between:

* **Background System Daemons:** Spotlight indexing (`mds`, `mdworker_shared`) and QuickLook satellites.


* **Current Working Directory (CWD) Locks:** Orphaned shells (`zsh`, `bash`, `node`) resting inside a folder on the volume.


* **Active Open File Handles:** Running apps holding read/write locks on specific files.



**Supported Platform:** macOS only, targeting **macOS 27.2.1 (build 26B131) only**. Other macOS versions and other operating systems are unsupported.

---

#### 2. Category & Theme Alignment

* **Target Category:** **Resurrection ($5,000)**


* **The Narrative Hook:** Resurrecting classic Mac single-purpose diagnostic tools (such as System 7/OS 9 *Put Away* inspectors and early OS X utilities like *What’s Keeping Me?*) re-engineered for the modern Darwin APFS kernel.


* **Visual Direction:** **Platinum Retro Gothic.** Styled like a classic System 7 / Mac OS 9 platinum alert window (pinstripe title bars, Monaco/Chicago typography, 1px beveled frames) haunted by the playful, glowing, Kiro-inspired ghost mascot (an original character, not the Kiro ghost).



---

#### 3. User Experience & Architecture

* **Trigger Mechanism:** Native Finder Quick Action (`Why Can't I Eject?` / `Inspect Volume Locks`) and Desktop drop-target—completely independent from menu-bar widgets to ensure distinct submission architecture.


* **Diagnostic Sheet (UI):**
* Displays the target volume name and path.


* Tabulates offending processes: Process Name, PID, User, Lock Category (CWD vs. Open File Handle), and exact file path.




* **Graduated Resolution Pipeline:**
1. *Egress Shells:* Resets idle shell working directories (`cd ~`) without killing terminal sessions.
2. *Graceful Request:* Dispatches standard AppKit quit / `SIGTERM` requests to active applications.
3. *Banish Locks:* Sends targeted `SIGKILL` to hung daemons or orphan workers.


4. *Clean Handoff:* Initiates standard unmounting via `DiskArbitration.framework` / `/usr/sbin/diskutil unmount` once locks hit zero.





---

#### 4. Kiro Hackathon Integration (Score Multipliers)

* **Spec-Driven Development (`.kiro/specs/`):** A comprehensive specification detailing mount-point path resolution, Darwin process discovery state machines, and safe unmount workflows.


* **Property-Based Testing (PBT):** Rigorous fuzz testing of the raw `lsof`/`fuser` POSIX output parser against malformed paths, non-UTF8 strings, spaces, and symlinks.


* **Agent Hooks (`.kiro/hooks/`):** Automated pre-commit hooks enforcing swiftlint rules and verifying test passes prior to commits.



---

#### 5. Competitive Deliverables Checklist

* **Codebase:** Standalone public GitHub repo with an OSI-compatible MIT license and clean commit history.


* **Root Workspace:** Visible `.kiro/` folder featuring specifications, steering files, and automated hooks.


* **Demo Video:** A $\le 3$-minute video showing a locked drive, Finder failing to unmount, PhantomTrace revealing the hidden process, and the safe eject execution.


---

#### 6. Status and Where to Look

* **Status:** scaffolding is complete (Swift package, CLI stub, lint, hooks, scripts, steering, specs). Feature logic, the CLI inspect command, and the AppKit app are not built yet. Current state: [README.md](../README.md) and [architecture.md](architecture.md).


* **Safety guardrails:** every action goes through one safety policy; protected processes and system volumes are never touched; each stage is opt-in, previewed, and re-verified against a fresh scan. See [architecture.md](architecture.md).


* **Design reference:** [LookAndFeel/README.md](LookAndFeel/README.md).


* **Work, tools, and decisions:** [ProjectLog.md](ProjectLog.md). **Kiro usage evidence:** [KiroUsage.md](KiroUsage.md). **Submission tracking:** [SubmissionChecklist.md](SubmissionChecklist.md). **Demo plan:** [demo-script.md](demo-script.md).

