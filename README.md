# Miorbi

Miorbi is a new macOS menu-bar and notch companion, developed independently from a behavior specification. The existing Notchly fork is not this repository's base: this project has its own source tree, assets, and Git history.

Planned features for the first GitHub test build:

- Apple Music controls and local, time-aligned lyric display when available.
- Local Codex task state, truthful approval/completion alerts, and opt-in five-hour and weekly usage display.
- A manual focus timer (15, 25, or 60 minutes), cumulative focus time, and two claimable pixel pets.
- Chinese/English settings and public bug/feature feedback links.

Privacy rules: task hooks must not persist prompts or tool contents; usage sync is off until the user opts in; no analytics or automatic log uploads. A missing permission or unsupported integration must be shown as unavailable, not simulated.

This is an early public test build, not a feature-complete V1. Synchronized
Apple Music lyrics are not implemented yet. Codex approval notifications,
usage sync, and the notch layout need real-machine testing; please report
false alerts or clipping through Issues.

All original source and included art are distributed under [MPL-2.0](LICENSE).
The new icon combines a black notch capsule with a focus countdown ring.

## Local preview build

Run `zsh Packaging/build-dmg.sh` on a Mac with Xcode. The result is
`dist/Miorbi-0.1.0-beta.1-arm64.dmg` on Apple silicon. Set
`MIORBI_ARCH=x86_64` to build the Intel DMG. These are ad-hoc signed,
unnotarized previews;
macOS may require an explicit Open Anyway action. We do not recommend
disabling Gatekeeper globally or running a blanket `sudo xattr` command.

This is a test release: synchronized lyrics and end-to-end UI verification
are still in progress.
