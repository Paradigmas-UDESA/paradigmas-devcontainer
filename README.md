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
  Mesa software rasterizer, and SFML 2.6.2 **built from source** with one
  upstream fix backported (Ubuntu's libsfml-dev cannot reliably open a
  window over VNC — read the long comment above the SFML block before
  touching it). Ubuntu 24.04 (noble) is pinned deliberately — see comments
  in the Dockerfile before changing the base.
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
   only — use it as the build check (it is what catches a `SFML_VERSION` bump
   that silently breaks the patch greps).

2. **Pick the tag.** `2026a` for the first publish of a course edition,
   `2026a.2` and onward for anything after students have started pulling.

3. **Dispatch the build.** **Actions → Build and push course image → Run
   workflow**, entering the tag. Or from the CLI:

   ```sh
   gh workflow run build-image.yml -f tag=2026a.2
   gh run watch
   ```

   The workflow has to exist on `main` for dispatch to be offered at all. Give
   it time: `linux/arm64` is built under QEMU emulation and compiles SFML from
   source, so this is much slower than a native build.

4. **Verify before pointing anyone at it** — see *Verifying a published image*
   below. The GUI repeat-run loop is not optional: the bug this image patches
   was a coin flip, so one successful launch proves nothing.

5. **Point the activity repos at the new tag.** Edit `image:` in
   `template/devcontainer.json`, then push it out:

   ```sh
   scripts/sync-devcontainer.sh \
     ../Clases/Clase\ 2 \
     ../Clases/Clase-3---Memoria-Dinamica \
     ../TP-Hive
   ```

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

### GUI path

The SFML/GLX bug this image patches (see the Dockerfile) failed on roughly
half of all runs, so a single successful launch proves nothing. Check that a
window opens on **every** run:

```sh
docker run --rm --init \
  --entrypoint /usr/local/share/desktop-init.sh \
  ghcr.io/paradigmas-udesa/paradigmas:2026a bash -c '
    sleep 4
    printf "%s\n" \
      "#include <SFML/Graphics.hpp>" \
      "int main(){ sf::RenderWindow w(sf::VideoMode::getDesktopMode(), \"t\");" \
      "            w.clear(); w.display(); }" > /tmp/w.cpp
    g++ /tmp/w.cpp -o /tmp/w -lsfml-graphics -lsfml-window -lsfml-system || exit 1
    fail=0
    for i in $(seq 1 20); do
      DISPLAY=:1 /tmp/w 2>/tmp/err || { fail=$((fail+1)); head -1 /tmp/err; }
    done
    echo "failures: $fail/20"
  '
```

`failures: 0/20` is the only acceptable result. Anything else means the SFML
patch did not apply — the Dockerfile has `grep` guards that should have
failed the build first.

Full rollout and verification checklist lives in the design plan this repo
was scaffolded from.
