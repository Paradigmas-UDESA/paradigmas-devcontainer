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
  devcontainer.json in the course allowed to declare `features` (it adds
  `desktop-lite` for the noVNC GUI path). Features declared here are baked
  into the pushed image at CI time.
- `template/devcontainer.json` — **what ships to activity repos**. Must stay
  feature-free and never build anything: an `image:` tag reference, the shared
  ccache volume, gdb `runArgs`, the noVNC port, and a `postStartCommand`.
  Runtime wiring (mounts, ports, `runArgs`) belongs here; anything that
  *installs or builds* does not — that cost would be paid by every student on
  every activity instead of once at image-build time.

Consequence for CI: the workflow builds with the **`devcontainer` CLI, not
`docker build`** — a bare `docker build` would silently omit `desktop-lite`,
producing an image where the GUI only works when a container is created from
source. Don't "simplify" that step.

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
  libraries (not just headers), and its apt tree carries the 2.6.x-era SFML
  dependency stack. The Dockerfile comment also cites "26.04 ships SFML 3,
  which is API-incompatible" — that reason is now partly historical, since
  SFML itself comes from the pinned source build below, not apt; what still
  has to come from the base are gtest and the `-dev` libraries SFML links
  against.
- **SFML 2.6.2 is built from source, not installed from apt**, to backport an
  upstream fix: SFML 2.6's `GlxContext::selectBestVisual()` scores X visuals
  from uninitialized locals, so on the VNC display it picks a visual GLX cannot
  make a context for on roughly half of runs ("Failed to get GLXFBConfig").
  The patch is a `sed` over `src/SFML/Window/Unix/GlxContext.cpp` guarded by
  `grep -q` checks — **bumping `SFML_VERSION` can make the `sed` silently
  no-op**, which is why the greps fail the build instead.
- **The SFML build block must stay above the `ccache` `ENV` block.** With
  `/usr/lib/ccache` on `PATH` and `CCACHE_DIR` set, that root-run build
  populates `/home/vscode/.ccache` as root and every student compile then dies
  with `ccache: error: Permission denied`.
- **ccache ownership is fixed in two places on purpose**: `mkdir`+`chown` in
  the image (seeds ownership for volumes created fresh) *and* the
  `postStartCommand` chown in `template/devcontainer.json` (Docker won't
  retroactively fix a volume already created root-owned). Removing either
  leaves a reachable broken state.
- `VNC_RESOLUTION=...x24` is a **display-quality** setting only. It does not
  fix the GLX crash (an earlier commit claimed it did); that crash is the SFML
  bug above.

## Verifying a published image

The GLX bug failed ~50% of runs, so **a single successful window launch proves
nothing** — always use the 20-iteration loop in `README.md` ("GUI path") and
accept only `failures: 0/20`. The README also has the manifest/architecture,
baked-feature, and toolchain-version checks.

Local iteration on the Dockerfile without publishing (same CLI as CI, minus
`--platform`/`--push`):

```sh
devcontainer build --workspace-folder . --image-name paradigmas:dev
```
