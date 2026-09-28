# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

There is no application code here. This repo builds and publishes **one
prebuilt, multi-arch container image** (`ghcr.io/paradigmas-udesa/paradigmas`)
used by every activity repo of the Paradigmas de Programación course (UDESA,
C++). The "product" is the image plus a tiny `devcontainer.json` that activity
repos copy in. Read `README.md` for the rollout/verification narrative.

## Architecture: the two-devcontainer.json split

This is the central design and the easiest thing to break.

- `.devcontainer/devcontainer.json` — **build source only**. The one and only
  devcontainer.json in the course allowed to declare `features` (none since
  `2026a.2`: `desktop-lite`/noVNC went with SFML). Features declared here are
  baked into the pushed image at CI time.
- `template/devcontainer.json` — **what ships to activity repos**. Must stay
  feature-free and never build anything: an `image:` tag reference, the shared
  ccache volume, gdb `runArgs`, and a `postStartCommand`.
  Runtime wiring (mounts, ports, `runArgs`) belongs here; anything that
  *installs or builds* does not — that cost would be paid by every student on
  every activity instead of once at image-build time.

Consequence for CI: the workflow builds with the **`devcontainer` CLI, not
`docker build`** — a bare `docker build` would silently omit any feature
declared there. There are none right now; keep the CLI anyway so adding one
later just works.

## Tag discipline

Never overwrite a tag students may already have pulled — a stale local image
against fresh bits is an irreproducible-bug generator.

- A push to `main` touching `Dockerfile`, `.devcontainer/**`, or the workflow
  publishes the throwaway **`edge`** tag only — a build check that no activity
  repo references. It cannot touch a course tag or `latest`.
- Publishing is always an explicit dispatch: **Actions → Build and push course
  image → Run workflow** with the tag (`2026a.2`), then edit `image:` in
  `template/devcontainer.json`, then sync it out.
- `latest` moves only on a dispatch of the default course tag (`2026a`) — both
  the event and the tag are checked, so a mid-semester `2026a.2` leaves
  `latest` alone.

Bumping the tag is a three-part change; doing only the first leaves activity
repos on the old image. `README.md` → *Publishing a new version* is the full
runbook (dispatch, verify, sync, tell students to rebuild).

```sh
scripts/sync-devcontainer.sh ../Clases/Clase\ 2 ../TP-Hive   # copies template/ into each repo's .devcontainer/
```

## Dockerfile invariants

Each of these is load-bearing and has a long comment above it; read the
comment before editing.

- **Base pinned to Ubuntu 24.04 (noble)**: noble ships prebuilt `libgtest-dev`
  libraries (not just headers).
- **No SFML, no VNC desktop since `2026a.2`.** GUIs are web pages served from
  the container (python3) and drawn by the host's browser. The SFML source
  build with its GLX patch lives in git history (and in the `2026a` image) if
  an activity ever needs it back.
- **ccache ownership is fixed in two places on purpose**: `mkdir`+`chown` in
  the image (seeds ownership for volumes created fresh) *and* the
  `postStartCommand` chown in `template/devcontainer.json` (Docker won't
  retroactively fix a volume already created root-owned). Removing either
  leaves a reachable broken state.

## Verifying a published image

`README.md` has the manifest/architecture and toolchain-version checks.

Local iteration on the Dockerfile without publishing (same CLI as CI, minus
`--platform`/`--push`):

```sh
devcontainer build --workspace-folder . --image-name paradigmas:dev
```
