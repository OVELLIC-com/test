# Changelog

## v0.0.5 — 2026-11-17

Fifth rehearsal release: the real signing tooling (sync_build.sh, sign-windows.sh,
attach-signatures.sh and release.yml) over this toy program. Windows binaries are
signed by the build pod and the signatures attached by the release workflow.

## v0.0.4 — 2026-11-05

Fourth rehearsal release: the main package also gets a release-<version>
dist-tag next to latest.

## v0.0.3 — 2026-11-04

Third rehearsal release: main and the tag are pushed separately, and publish
waits out the registry's read lag.

## v0.0.2 — 2026-11-04

Second rehearsal release: the greeting changes. Checks that an ordinary
sync push, with the workflow already in place, triggers the release.

## v0.0.1 — 2026-11-04

First rehearsal release: synced by the simulated build pod with signed Windows
binaries, then built, signed, published and released by the release workflow.
