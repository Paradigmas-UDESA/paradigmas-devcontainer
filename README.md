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

## Layout

- `Dockerfile` — the toolchain: g++, make/cmake, gdb/valgrind, googletest,
  SFML 2.6 + Mesa software rasterizer. Ubuntu 24.04 (noble) is pinned
  deliberately — see comments in the Dockerfile before changing the base.
- `.devcontainer/devcontainer.json` — the **build source**. This is the only
  devcontainer.json in the whole course allowed to list `features` (it adds
  `desktop-lite` for the noVNC GUI path). Features here get baked into the
  pushed image; they must never appear in an activity repo's config.
- `template/devcontainer.json` — what actually gets copied into every
  activity repo. Tiny and feature-free by design: an `image:` reference, a
  shared ccache volume, the gdb/ptrace `runArgs`, and the noVNC port.
- `.github/workflows/build-image.yml` — builds `linux/amd64` + `linux/arm64`
  via the `devcontainer` CLI (not a bare `docker build`, so features are
  actually installed) and pushes to `ghcr.io/paradigmas-udesa/paradigmas`.
- `scripts/sync-devcontainer.sh` — pushes `template/devcontainer.json` into
  one or more activity repos. Run it whenever you bump the image tag.

## Publishing a new image

1. Edit the `Dockerfile` and/or `.devcontainer/devcontainer.json`.
2. Push to `main`, or run the workflow manually via **Actions → Build and
   push course image → Run workflow**, entering the tag (e.g. `2026a.2`).
3. **Never overwrite an existing tag mid-semester.** A student who already
   pulled `2026a` keeps the old bits while a fresh pull gets new ones —
   that's an irreproducible-bug generator. Bump to `2026a.2`, update
   `template/devcontainer.json`'s `image:` field, then sync it out:

   ```sh
   scripts/sync-devcontainer.sh \
     ../Clases/Clase\ 2 \
     ../Clases/Clase-3---Memoria-Dinamica \
     ../TP-Hive
   ```

4. Make sure the GHCR package is set to **public** (Package settings →
   Change visibility) so students can pull without `docker login`.

## Verifying a published image

```sh
# Both architectures present?
docker manifest inspect ghcr.io/paradigmas-udesa/paradigmas:2026a

# Feature really baked in, not something students install at create-time?
docker run --rm ghcr.io/paradigmas-udesa/paradigmas:2026a \
  ls /usr/local/share/desktop-init.sh

# Toolchain sanity
docker run --rm ghcr.io/paradigmas-udesa/paradigmas:2026a bash -c '
  g++ --version &&
  pkg-config --modversion sfml-graphics &&
  ls /usr/lib/*/libgtest* &&
  gdb --version &&
  valgrind --version
'
```

Full rollout and verification checklist lives in the design plan this repo
was scaffolded from.
