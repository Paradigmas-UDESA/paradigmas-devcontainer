# paradigmas-devcontainer

Source of the shared course image for **Paradigmas de Programación** (UDESA,
C++). One prebuilt, multi-arch image, published once per course edition, so
every activity repo just references it by tag instead of building or
installing anything on a student's machine.

## Why

Per-activity environment setup used to be a mess of OS-specific README
instructions (Homebrew SFML on macOS, apt on Linux, an Apple-Silicon-specific
variant folder, a warning that newer Ubuntu ships an API-incompatible SFML
3). This repo replaces all of that with one image containing the exact
toolchain every activity needs.

Since `2026a.2` the image has **no SFML and no VNC desktop**: GUIs are web
pages served from the container (a few lines of `python3 -m http.server`)
and drawn by the host's browser. Activities that still use SFML stay on
`2026a`, which is never overwritten.

## Layout

- `Dockerfile` — the toolchain: g++, make/cmake, gdb/valgrind, googletest,
  Boost (headers), python3 (GUI servers). Ubuntu 24.04 (noble) is pinned
  deliberately — see comments in the Dockerfile before changing the base.
- `.devcontainer/devcontainer.json` — the **build source**. This is the only
  devcontainer.json in the whole course allowed to list `features` (none
  since `2026a.2`). Features here get baked into the
  pushed image; they must never appear in an activity repo's config.
- `template/devcontainer.json` — what actually gets copied into every
  activity repo. Tiny and feature-free by design: an `image:` reference, a
  shared ccache volume and the gdb/ptrace `runArgs`.
- `.github/workflows/build-image.yml` — builds `linux/amd64` + `linux/arm64`
  via the `devcontainer` CLI (not a bare `docker build`, so features are
  actually installed) and pushes to `ghcr.io/paradigmas-udesa/paradigmas`.
  Course tags come only from a manual dispatch; a push to `main` republishes
  the throwaway `edge` tag.
- `scripts/sync-devcontainer.sh` — pushes `template/devcontainer.json` into
  one or more activity repos. Run it whenever you bump the image tag.

## Publishing a new version

Publishing is always deliberate: a push to `main` rebuilds only the throwaway
`edge` tag, and a course tag is written *only* by a manual workflow dispatch.

**The rule that shapes the rest: never overwrite a tag a student may already
have pulled.** They keep the old bits while a fresh pull gets new ones — an
irreproducible-bug generator. Mid-semester fixes get a new tag (`2026a.2`,
`2026a.3`, …); `2026a` itself is only ever written before the semester starts.

1. **Edit and land the change.** Change the `Dockerfile` and/or
   `.devcontainer/devcontainer.json` and push to `main`. That publishes `edge`
   only — use it as the build check.

2. **Pick the tag.** `2026a` for the first publish of a course edition,
   `2026a.2` and onward for anything after students have started pulling.

3. **Dispatch the build.** **Actions → Build and push course image → Run
   workflow**, entering the tag. Or from the CLI:

   ```sh
   gh workflow run build-image.yml -f tag=2026a.2
   gh run watch
   ```

   The workflow has to exist on `main` for dispatch to be offered at all. Give
   it time: `linux/arm64` is built under QEMU emulation, so this is slower
   than a native build.

4. **Verify before pointing anyone at it** — see *Verifying a published image*
   below.

5. **Point the activity repos at the new tag.** Edit `image:` in
   `template/devcontainer.json`, then push it out:

   ```sh
   scripts/sync-devcontainer.sh ../TP2
   ```

   Only repos that work on the new tag: `2026a.2` has no SFML, so an SFML
   activity (TP-Hive) must stay on `2026a`.

   Commit the bump here *and* the synced file in each activity repo — a tag
   nobody references has not actually shipped.

6. **Tell students to rebuild.** An already-created container keeps running the
   old image until they run **Dev Containers: Rebuild Container**; pulling the
   new tag happens as part of that rebuild.

First publish of an edition only: make sure the GHCR package is set to
**public** (Package settings → Change visibility) so students can pull without
`docker login`.

## Verifying a published image

```sh
# Both architectures present?
docker manifest inspect ghcr.io/paradigmas-udesa/paradigmas:2026a

# Toolchain sanity
docker run --rm ghcr.io/paradigmas-udesa/paradigmas:2026a bash -c '
  g++ --version &&
  python3 --version &&
  ls /usr/include/boost/math/tools/roots.hpp &&
  ls /usr/lib/*/libgtest* &&
  gdb --version &&
  valgrind --version
'
```

Full rollout and verification checklist lives in the design plan this repo
was scaffolded from.
