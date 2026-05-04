# Script City

![License](https://img.shields.io/github/license/Nuxview/useful-scripts?color=blue)
![Repo Size](https://img.shields.io/github/repo-size/Nuxview/useful-scripts)
![Last Commit](https://img.shields.io/github/last-commit/Nuxview/useful-scripts)

A collection of comprehensive Bash scripts designed to simplify development environment setup, system maintenance, and DevOps workflows.

## 📂 Repository Contents

| Script | Purpose | Detailed Docs |
| :--- | :--- | :--- |
| **Arch Virtualization Setup** | Installs Docker, KVM/QEMU, LXC/LXD, and Nix with a single command. | [View README](./arch-virtualization-setup/README.md) |
| **Docker Prune** | A compose-aware utility that surgically removes project-specific Docker resources. | [View README](./docker-prune/README.md) |

---

## 🚀 Script Details

### 1. Arch Virtualization Setup
A powerful script to set up a complete virtualization and containerization stack on Arch-based systems. It features an interactive TUI for personalized setups.

*   **Key Features:** Docker (Compose/Buildx), KVM/QEMU, LXC/LXD, and Nix.
*   **Quick Start:**
    ```bash
    cd arch-virtualization-setup
    chmod +x arch-virt-setup.sh
    ./arch-virt-setup.sh
    ```

### 2. Docker Prune
A surgical cleanup tool for Docker Compose projects. Unlike a global `docker system prune`, this script is scoped to the project in your current directory.

*   **Key Features:** Dry-run mode, volume protection, and build cache clearing.
*   **Quick Start:**
    ```bash
    cd your-project-dir
    /path/to/docker-prune.sh --dry-run
    ```
    > **Note:** The `--dry-run` flag allows you to see a simulation of what will be deleted without actually performing any actions. To execute the cleanup for real, simply run the command without the `--dry-run` flag.

---

## 📥 Downloading Individual Scripts

If you only need the executable script without cloning the entire repository, you can use `curl`:

**Arch Virtualization Setup:**
```bash
curl -O https://raw.githubusercontent.com/Nuxview/useful-scripts/main/arch-virtualization-setup/arch-virt-setup.sh
chmod +x arch-virt-setup.sh
```

**Docker Prune:**
```bash
curl -O https://raw.githubusercontent.com/Nuxview/useful-scripts/main/docker-prune/docker-prune.sh
chmod +x docker-prune.sh
```

## 📜 License
This repository and its scripts are licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
