# BlueOS releases

Builds BlueOS images from a pinned BlueOS commit, publishes them, and serves the release manifest devices read.

This repository exists separately from [BlueOS](https://github.com/BlueRobotics/BlueOS) so that images can be tagged on their own schedule, independently of the Docker container releases. BlueOS itself builds and caches; this repository decides what counts as a release.

## What a release is

A release is a git tag whose name matches the BlueOS version in the commit being released. The tag is both the GitHub release name and the manifest entry, so they cannot disagree.

The version is not set here. It comes from `etc/blueos/release.json` in the built closure, which BlueOS writes from the version literal in `nix/packages/blueos-source`. `lib.mkImage` accepts a `version` argument, but it reaches the release metadata and the generation label without reaching the built frontend, so overriding it here would make one device report two versions. The workflow therefore refuses to build a tag whose name differs from the version in the closure.

## Releasing

1. Bump `version` in BlueOS's `nix/packages/blueos-source/default.nix` and merge it.
2. Update `blueos.url` here to that commit. The revision is in the URL rather than left to `flake.lock`, so `nix flake update` cannot move it:

   ```fish
   nix flake lock
   ```

3. Tag and push:

   ```fish
   git tag 1.5.0
   git push origin 1.5.0
   ```

The workflow checks the tag against the version, builds the four images (pi4 and pi5, kernel and system), pushes each closure to the binary cache, then writes the manifest and attaches the `.img.zst` files to the GitHub release.

Ordering matters and the job graph enforces it: a closure reaches the cache before the manifest names it, and the manifest is published before the images are attached. A device that sees a release can always download it.

## The manifest

`gh-pages` holds exactly two files, `manifest.json` and `index.html`, and is served at <https://bluerobotics.github.io/BlueOS-releases/>. A bare `/manifest.json` would 404 because Pages serves `index.html` from the site root, which is why the branch carries that file.

The manifest is keyed on `(board, version)` and keeps only the newest entry, so re-running an old tag replaces that entry rather than adding a second one. When the rebuild is byte-for-byte the one already listed, its original `published` timestamp is kept, so re-running a tag changes nothing.

Entries carry `board`, `channel`, `version`, `revision`, `toplevel` and `published`. `toplevel` is the store path the daemon realises; it is why the cache push has to happen first, and why the manifest and the trusted cache key have to describe the same deployment.

## Configuration

`flake.nix` holds the endpoint choices in one place:

| Value | What it must be |
| --- | --- |
| `manifestUrl` | Where this repository serves `manifest.json` |
| `cache.host` | The binary cache devices trust |
| `cache.publicKey` | That cache's public key |

Both currently point at the cache that the standalone `blueos-nix` flake used. They are placeholders: a published manifest names store paths, and devices can only realise them from a cache whose key they trust, so the two must be replaced together with BlueRobotics-owned infrastructure.

## Requirements

The workflow expects three values on the repository, none of which are in source:

- `vars.NIKS3_SERVER_URL` and `vars.NIKS3_PUBLIC_KEY`, the cache and its key
- `secrets.NIKS3_AUTH_TOKEN`, which authorises pushes to it

`ubuntu-24.04-arm` runners build the images natively. There is no cross-compiled variant: the systems are `aarch64-linux`, so an x86_64 host would need `boot.binfmt.emulatedSystems` and a much longer build.

## Current state

`blueos.url` points at the head of [PR BlueRobotics/BlueOS#4698](https://github.com/BlueRobotics/BlueOS/pull/4698), because the flake does not exist on `master` yet. GitHub cannot serve a flake from that commit until it is merged, so `nix flake lock` fails against the GitHub URL and the workflow cannot run. Move the pin to a `master` commit once the PR lands, and remove the local override in the meantime:

```fish
nix flake lock --allow-dirty-locks \
  --override-input blueos 'git+file:///path/to/BlueOS'
```
