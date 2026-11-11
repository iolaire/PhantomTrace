# Product

PhantomTrace is a retro-themed macOS contextual forensic utility that demystifies Finder's opaque "The disk wasn't ejected because one or more programs may be using it" dialog. It pinpoints the exact locking processes and open file handles, so users can safely resolve blockers and unmount external drives.

Given a volume (external drive, USB stick, or mounted `.dmg`), it resolves the mount point, lists the processes holding locks, classifies each lock (background system daemon, CWD lock, or open file handle), and offers a graduated, opt-in resolution pipeline: Egress Shells, Graceful Request, Banish Locks, Clean Handoff.

Mission: identify which processes prevent a volume from ejecting.

The full overview is in `docs/ProjectOverview.md`.

## Hackathon theme

PhantomTrace targets the Resurrection category. It resurrects classic single-purpose Mac diagnostic tools (System 7 / OS 9 inspectors, *What's Keeping Me?*) for modern macOS, and brings stuck, "haunted" volumes back under the user's control.

## Visual direction

Platinum Retro Gothic: System 7 / Mac OS 9 platinum alert window (pinstripe title bars, Monaco/Chicago typography, 1px beveled frames) with the Kiro ghost mascot.

## Trigger

A native Finder Quick Action and a Desktop drop target, independent of any menu-bar widget.

## Platform target

- macOS only. No other operating system is supported.
- macOS 27.2.1 (build 26B131) only.
- Every other macOS version, older or newer, is out of scope and unsupported; it cannot be tested.

## Source of truth

The master spec is `.kiro/specs/phantomtrace-volume-lock-forensics/`. Do not modify it from scaffolding work.
