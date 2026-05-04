# Changelog

All notable changes to this repository are documented here in reverse-chronological order.

---

## [fae5e6a] — 2026-05-03T20:20:46Z

**Full SHA:** `fae5e6ace2654f0eff3447906f29fc7e54e8f04d`  
**Author:** coderabbitai[bot]  
**Subject:** fix: apply CodeRabbit auto-fixes

**Changed files:**
- `arch-virtualization-setup/arch-virt-setup.sh` — 1 deletion

**Summary:** Removed a stray blank/redundant line in the virt-setup script as suggested by CodeRabbit's automated review.

---

## [655d0d4] — 2026-04-30T14:12:58+03:00

**Full SHA:** `655d0d46c0269044086b38fb7ac031420ec38af5`  
**Author:** Alex Mercer  
**Subject:** Update arch-virtualization-setup/arch-virt-setup.sh

**Changed files:**
- `arch-virtualization-setup/arch-virt-setup.sh` — 3 insertions, 2 deletions

**Summary:** Minor fix to the virt-setup script (3 lines changed).

---

## [9882204] — 2026-04-30T14:12:13+03:00

**Full SHA:** `98822041989d7c48c38255b543407fa717e3f78f`  
**Author:** Alex Mercer  
**Subject:** Update docker-prune/README.md

**Changed files:**
- `docker-prune/README.md` — 1 insertion, 1 deletion

**Summary:** Minor documentation fix in the docker-prune README (1 line changed).

---

## [5e14fa3] — 2026-04-30T13:57:05+03:00

**Full SHA:** `5e14fa36007fe56c00d51671a02cc98bbecdb566`  
**Author:** Alex Mercer  
**Subject:** Update docker-prune/README.md

**Changed files:**
- `docker-prune/README.md` — 1 insertion, 1 deletion

**Summary:** Minor documentation fix in the docker-prune README (1 line changed).

---

## [2d1848c] — 2026-04-29T12:52:34+03:00

**Full SHA:** `2d1848cfb645e4959a61f0f8a95f5a83a1bcebc2`  
**Author:** Shaka Maina  
**Subject:** Add cleanup for Nix installer script and improve confirmation handling

**Changed files:**
- `arch-virtualization-setup/arch-virt-setup.sh` — 8 insertions, 2 deletions

**Summary:** Added a `trap`-based cleanup for the Nix installer temp file so it is reliably removed after use. Also improved the confirmation prompt handling around the remote Nix installer execution to prevent accidental non-interactive runs.

---

## [7ffae06] — 2026-04-29T11:44:48+03:00

**Full SHA:** `7ffae062fb2802c9509260a9499aa35158e35c3c`  
**Author:** Alex Mercer  
**Subject:** Potential fix for pull request finding

**Changed files:**
- `arch-virtualization-setup/arch-virt-setup.sh` — 72 insertions, 1 deletion

**Summary:** Expanded the Nix setup section substantially — added the full in-place `awk`-based rewrite of `experimental-features` in `nix.conf` to prevent duplicate entries, and switched `nix-direnv` path resolution from the broken `nix eval --raw` to `nix build --no-link --print-out-paths`.

---

## [a6df1c8] — 2026-04-29T11:43:27+03:00

**Full SHA:** `a6df1c8ad040da0165d6f802eb1590f4ffd7dd6c`  
**Author:** Alex Mercer  
**Subject:** Potential fix for pull request finding

**Changed files:**
- `arch-virtualization-setup/arch-virt-setup.sh` — 18 insertions, 1 deletion

**Summary:** Added the `next_subid_start` helper function and improved sub-UID/GID range handling so the script correctly computes a non-overlapping starting offset for new entries in `/etc/subuid` and `/etc/subgid`.

---

## [4627d16] — 2026-04-29T11:42:40+03:00

**Full SHA:** `4627d16cdb1617ed061efb05bdde66e6d83acbd9`  
**Author:** Alex Mercer  
**Subject:** Potential fix for pull request finding

**Changed files:**
- `arch-virtualization-setup/arch-virt-setup.sh` — 7 insertions, 2 deletions

**Summary:** Refined sysctl config handling — the script now checks whether `/etc/sysctl.d/99-arch-virt-setup-lxc.conf` already exists before writing it, making the LXC setup step idempotent and non-destructive for users who have edited that file.

---

## [27ca00f] — 2026-04-29T11:42:04+03:00

**Full SHA:** `27ca00f682f5cc43d1146e7404a35707fef3fba8`  
**Author:** Alex Mercer  
**Subject:** Potential fix for pull request finding

**Changed files:**
- `arch-virtualization-setup/arch-virt-setup.sh` — 1 insertion

**Summary:** Small incremental fix to the virt-setup script (1 line added).

---

## [f1072bd] — 2026-04-29T11:37:49+03:00

**Full SHA:** `f1072bd83eaa469d3349007bdd1cf1629e3da828`  
**Author:** Alex Mercer  
**Subject:** Potential fix for pull request finding

**Changed files:**
- `arch-virtualization-setup/arch-virt-setup.sh` — 1 insertion

**Summary:** Small incremental fix to the virt-setup script (1 line added).

---

## [53d87ee] — 2026-04-29T11:26:13+03:00

**Full SHA:** `53d87ee4225b483255da5c523ff3d28c18f132ba`  
**Author:** Shaka Maina  
**Subject:** fix: update non-interactive mode handling and improve README for clarity

**Changed files:**
- `arch-virtualization-setup/arch-virt-setup.sh` — 42 insertions, 15 deletions
- `docker-prune/README.md` — 2 changes
- `docker-prune/docker-prune.sh` — 1 change

**Summary:** Overhauled non-interactive mode (`--docker`, `--kvm`, etc. flags now set `NONINTERACTIVE=true`). Docker and KVM service-start failures now `return 1` to prevent false "setup complete" messages. The docker-prune README `--no-networks` description was updated to accurately reflect that `compose down` still removes the default project network regardless of this flag.

---

## [3d74c6a] — 2026-04-29T11:04:18+03:00

**Full SHA:** `3d74c6a8e07996aa9366ebcad30e7a7fe571e702`  
**Author:** Shaka Maina  
**Subject:** Merge branch 'feature/docs-and-scripts' of github.com:Nuxview/useful-scripts into feature/docs-and-scripts

**Changed files:**
- `arch-virtualization-setup/arch-virt-setup.sh` — 3 insertions, 1 deletion

**Summary:** Merge commit resolving diverged local and remote state of the feature branch.

---

## [70da30b] — 2026-04-29T10:59:16+03:00

**Full SHA:** `70da30b30a41a9d6aef60396ac5731ffe1f44583`  
**Author:** Shaka Maina  
**Subject:** feat: add next_subid_start function and improve sub-uid/gid mapping logic

**Changed files:**
- `arch-virtualization-setup/arch-virt-setup.sh` — 19 insertions, 2 deletions

**Summary:** Introduced the `next_subid_start` helper that reads `/etc/subuid` or `/etc/subgid` and returns the next safe starting offset beyond all existing ranges, preventing overlapping UID/GID mappings for unprivileged LXC containers.

---

## [1e1c776] — 2026-04-29T10:57:59+03:00

**Full SHA:** `1e1c7760f199d656abb3e5a45353dfac68c122d3`  
**Author:** Alex Mercer  
**Subject:** Apply suggestion from @coderabbitai[bot]

**Changed files:**
- `arch-virtualization-setup/arch-virt-setup.sh` — 3 insertions, 1 deletion

**Summary:** Applied a CodeRabbit suggestion to the virt-setup script (minor improvement, 4 lines changed).

---

## [81e6f6d] — 2026-04-29T10:47:01+03:00

**Full SHA:** `81e6f6d3da0c41129c2cbca43357e105b2da4810`  
**Author:** Shaka Maina  
**Subject:** docs: update README and script comments for clarity and accuracy

**Changed files:**
- `arch-virtualization-setup/README.md` — 17 lines changed
- `arch-virtualization-setup/arch-virt-setup.sh` — 12 lines changed
- `docker-prune/README.md` — 45 lines changed
- `docker-prune/docker-prune.sh` — 68 lines changed

**Summary:** Comprehensive documentation and script-comment pass. Key changes: Quick Start in `arch-virtualization-setup/README.md` now clones the correct repo (`Nuxview/useful-scripts`). The `--no-networks` flag in `docker-prune.sh` now drives a real label-based network sweep (step 5/7). The `run()` function was rewritten to use proper array invocation `"${cmd[@]}"` instead of `eval`. The internet connectivity check was updated to prefer `curl --head` over `ping`. Service-start error messages and help text were improved throughout.

---

## [d5cd0b2] — 2026-04-29T10:00:55+03:00

**Full SHA:** `d5cd0b2f1d738ec56e072f9954171e0a2181c574`  
**Author:** Alex Mercer  
**Subject:** Apply suggestions from code review

**Changed files:**
- `README.md` — 1 change
- `arch-virtualization-setup/arch-virt-setup.sh` — 9 insertions, 2 deletions
- `docker-prune/README.md` — 1 change

**Summary:** Applied automated code-review suggestions. Fixed the root `README.md` Last Commit badge to use the standard Shields.io endpoint. Updated the `docker-prune/README.md` LICENSE link from `LICENSE` to `../LICENSE`. Improved connectivity and prerequisite checks in the virt-setup script.

---

## [c205623] — 2026-04-28T13:57:28+03:00

**Full SHA:** `c20562369ce4caa60c5027fb36868bf6305f2b90`  
**Author:** Shaka Maina  
**Subject:** docs: add comprehensive root README and organize scripts

**Changed files:**
- `README.md` — 61 insertions (new file)
- `arch-virtualization-setup/README.md` — 224 insertions (new file)
- `arch-virtualization-setup/arch-virt-setup.sh` — 551 insertions (new file)
- `docker-prune/README.md` — 375 insertions (new file)
- `docker-prune/docker-prune.sh` — 232 insertions (new file)

**Summary:** Initial addition of the two main scripts and all documentation. Added the root `README.md` with repo overview, script summary table, quick-start commands, download-without-cloning instructions, and MIT license reference. Added `arch-virtualization-setup/` with a full Bash installer for Docker, KVM/QEMU/libvirt, LXC/LXD, and Nix, plus a detailed README covering requirements, interactive and CLI usage, per-tool details, post-install notes, and troubleshooting. Added `docker-prune/` with a Compose-aware Docker cleanup script (dry-run, volume/image/network/cache flags, global prune option) plus a comprehensive README covering usage recipes, safety notes, and FAQ.

---

## [febc60f] — 2026-04-27T16:18:26+03:00

**Full SHA:** `febc60fc640ad23798cc595367f7edbc58fbaaf9`  
**Author:** Shaka Maina  
**Subject:** Initial commit

**Changed files:**
- `LICENSE` — 21 insertions (new file)

**Summary:** Repository created. Added the MIT `LICENSE` file.

---

*Generated from `git log` on 2026-05-04.*
