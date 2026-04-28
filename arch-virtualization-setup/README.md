# Arch Virtualization and Containerization Setup

A single Bash script that sets up a complete development and virtualisation
environment on any **Arch-based Linux distribution** — Arch, CachyOS,
Manjaro, EndeavourOS, Garuda, and more.

It can install any combination of:

| Tool | What it's for |
|------|---------------|
| **Docker** | Running isolated application containers |
| **KVM / QEMU** | Full virtual machines (great for testing other OSes) |
| **LXC / LXD** | Lightweight OS containers |
| **Nix** | Reproducible dev shells and per-project environments |

---

## Requirements

- An Arch-based distro with `pacman`
- A regular user account with `sudo` access (do **not** run as root)
- An active internet connection

No other setup needed — the script handles everything else, including
installing an AUR helper (`yay`) if one isn't already present.

---

## Quick Start

```bash
# 1. Clone the repo
git clone git@github.com:Nixjoyer/arch-virtualization-setup.git
cd arch-virtualization-setup

# 2. Make the script executable
chmod +x arch-virt-setup.sh

# 3. Run it
./arch-virt-setup.sh
```

With no flags the script opens an interactive menu where you pick what
to install.

---

## Usage

### Interactive menu (recommended)

```bash
./arch-virt-setup.sh
```

You'll see a numbered menu:

```
  1) Docker only
  2) KVM / QEMU / libvirt only
  3) LXC / LXD only
  4) Nix only
  5) Docker + Nix        (code dev stack)
  6) KVM + LXC           (OS exploration stack)
  7) Docker + KVM
  8) Docker + LXC
  9) All (Docker + KVM + LXC + Nix)
  q) Quit
```

### CLI flags (for scripting / automation)

You can skip the menu entirely by passing one or more flags:

```bash
./arch-virt-setup.sh --docker          # Docker only
./arch-virt-setup.sh --nix             # Nix only
./arch-virt-setup.sh --docker --nix    # Docker + Nix
./arch-virt-setup.sh --kvm --lxc       # KVM + LXC
./arch-virt-setup.sh --all             # Everything
```

---

## What each section installs

### Docker

- `docker`, `docker-compose`, `docker-buildx`
- Enables and starts the Docker daemon (`systemd`)
- Adds your user to the `docker` group
- Optional: `lazydocker` — a terminal UI for managing containers

### KVM / QEMU / libvirt

- `qemu-full`, `libvirt`, `virt-manager`, `virt-viewer`
- Bridge networking tools: `dnsmasq`, `bridge-utils`
- UEFI support: `edk2-ovmf`
- TPM emulation: `swtpm`
- Enables `libvirtd` and activates the default NAT network
- Adds your user to the `libvirt` and `kvm` groups
- Checks for Intel VT-x / AMD-V support before proceeding

### LXC / LXD

- `lxc` (from pacman) and `lxd` (from AUR)
- Configures `sysctl` settings for unprivileged containers
- Sets up `subuid` / `subgid` ID mappings for your user
- Checks for cgroup v2 (required by modern LXD)
- Enables and starts the `lxd` daemon

### Nix

- Installs Nix using the **Determinate Systems installer** — the
  recommended approach for non-NixOS systems. It sets up the
  multi-user daemon and enables flakes automatically.
- Ensures `experimental-features = nix-command flakes` is set in
  `~/.config/nix/nix.conf`
- Optional: `direnv` + `nix-direnv` — automatically activates a
  project's Nix shell when you `cd` into the directory
- Optional: `nh` — a Nix helper TUI for running and switching flakes
- Optional: `nix-search-cli` — search nixpkgs from the terminal

---

## After Installation

### Group membership

Most tools add your user to a system group. This only takes effect in a
**new login session**. To apply it immediately in your current terminal:

```bash
newgrp docker     # for Docker
newgrp libvirt    # for KVM
newgrp lxd        # for LXC/LXD
```

### Nix shell

Open a new terminal (or source the profile manually) before using `nix`:

```bash
source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

---

## Quick Command Reference

### Docker

```bash
# Verify install
docker run --rm hello-world

# Build and run a project
docker compose up --build
```

### KVM

```bash
# Open the graphical VM manager
virt-manager

# List all virtual machines
virsh list --all
```

### LXC / LXD

```bash
# First-time setup wizard
sudo lxd init

# Launch an Ubuntu container
lxc launch ubuntu:22.04 my-container

# Open a shell inside it
lxc exec my-container -- bash

# List running containers
lxc list
```

### Nix

```bash
# Start a temporary shell with packages (nothing installed permanently)
nix shell nixpkgs#python3 nixpkgs#nodejs

# Run a package without installing it
nix run nixpkgs#cowsay -- "Hello from Nix"

# Initialise a flake in your project
nix flake init

# If using direnv: activate the project's flake shell automatically
echo "use flake" > .envrc && direnv allow
```

---

## Tested On

- CachyOS
- Arch Linux
- Manjaro
- EndeavourOS

Should work on any distro that uses `pacman` and `systemd`.

---

## Notes

- The script will **not run as root** — this is intentional. Package
  builds (like installing `yay`) must be done as a regular user.
- Running the script more than once is safe. Pacman's `--needed` flag
  skips packages that are already installed, and the Nix section
  detects an existing installation and skips the installer.
- The script runs `pacman -Syu` at the start to avoid partial upgrade
  issues. This is standard practice on Arch.
