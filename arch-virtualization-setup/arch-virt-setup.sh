#!/usr/bin/env bash
# =============================================================================
#  arch-virt-setup.sh
#  Sets up Docker, KVM, LXC, and/or Nix on Arch-based Linux distributions.
#  Supports: Arch Linux, Manjaro, EndeavourOS, Garuda, CachyOS, etc.
#
#  Usage:
#    chmod +x arch-virt-setup.sh
#    ./arch-virt-setup.sh [--docker] [--kvm] [--lxc] [--nix] [--all]
#
#  With no flags, an interactive menu is shown.
# =============================================================================

set -euo pipefail

# ─── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ─── Helpers ──────────────────────────────────────────────────────────────────
info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
die()     { error "$*"; exit 1; }
section() { echo -e "\n${BOLD}${BLUE}══════════════════════════════════════════${RESET}"; \
            echo -e "${BOLD}${BLUE}  $*${RESET}"; \
            echo -e "${BOLD}${BLUE}══════════════════════════════════════════${RESET}"; }

pause() {
    echo -e "\n${YELLOW}Press [Enter] to continue...${RESET}"
    read -r
}

helper_needed() {
    $SETUP_LXC || $WANT_NIX_SEARCH_CLI
}

next_subid_start() {
    local file="$1"
    local range="$2"
    local max_end
    max_end=$(awk -F: 'NF>=3 { end=$2+$3; if (end>max) max=end } END { print max+0 }' "$file" 2>/dev/null)
    if [[ -z "$max_end" || "$max_end" -eq 0 ]]; then
        echo 100000
    else
        echo "$max_end"
    fi
}

# ─── Pre-flight checks ────────────────────────────────────────────────────────
check_root() {
    if [[ $EUID -eq 0 ]]; then
        die "Do not run this script as root. Run as a regular user with sudo access."
    fi
}

check_sudo() {
    if ! sudo -v 2>/dev/null; then
        die "sudo is required. Make sure your user has sudo privileges."
    fi
}

check_arch() {
    if ! command -v pacman &>/dev/null; then
        die "pacman not found. This script only supports Arch-based distributions."
    fi
}

check_internet() {
    info "Checking internet connectivity..."
    if command -v curl &>/dev/null; then
        if ! curl -fsS --head --connect-timeout 5 --max-time 10 https://archlinux.org/ &>/dev/null; then
            die "No internet connection. Please connect and retry."
        fi
    else
        warn "curl not found; falling back to ping-based connectivity check."
        if ! ping -c1 -W3 archlinux.org &>/dev/null; then
            die "No internet connection. Please connect and retry."
        fi
    fi
    success "Internet OK."
}

detect_distro() {
    DISTRO="Unknown"
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        DISTRO="${NAME:-Unknown}"
    fi
    info "Detected distro: ${BOLD}${DISTRO}${RESET}"
}

# ─── AUR helper ───────────────────────────────────────────────────────────────
ensure_aur_helper() {
    for helper in yay paru; do
        if command -v "$helper" &>/dev/null; then
            AUR_HELPER="$helper"
            info "AUR helper found: ${BOLD}${AUR_HELPER}${RESET}"
            return
        fi
    done

    warn "No AUR helper found. Installing yay..."
    sudo pacman -S --needed --noconfirm git base-devel

    local tmpdir
    tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
    pushd "$tmpdir/yay" > /dev/null
    makepkg -si --noconfirm
    popd > /dev/null
    rm -rf "$tmpdir"

    AUR_HELPER="yay"
    success "yay installed successfully."
}

# ─── System update ────────────────────────────────────────────────────────────
update_system() {
    section "System Update"
    info "Updating package database and upgrading packages..."
    sudo pacman -Syu --noconfirm
    success "System is up to date."
}

# ─── Docker ───────────────────────────────────────────────────────────────────
setup_docker() {
    section "Docker Setup"

    info "Installing Docker and Docker Compose..."
    sudo pacman -S --needed --noconfirm docker docker-compose docker-buildx

    info "Enabling and starting Docker daemon..."
    sudo systemctl enable --now docker

    info "Adding ${BOLD}${USER}${RESET} to the docker group..."
    sudo usermod -aG docker "$USER"

    # Verify docker socket is up
    if sudo systemctl is-active --quiet docker; then
        success "Docker service is running."
    else
        error "Docker service failed to start. Check: journalctl -xe -u docker"
        return 1
    fi

    # Optional: install lazydocker (TUI for Docker) via AUR
    if [[ -n "${AUR_HELPER:-}" ]] && command -v "$AUR_HELPER" &>/dev/null; then
        if [[ "$NONINTERACTIVE" == true ]]; then
            install_lazy="n"
        else
            read -rp "$(echo -e "${YELLOW}Install lazydocker (Docker TUI)? [y/N]: ${RESET}")" install_lazy
        fi
        if [[ "${install_lazy,,}" == "y" ]]; then
            "$AUR_HELPER" -S --noconfirm lazydocker-bin
            success "lazydocker installed."
        fi
    fi

    echo
    warn "Docker group membership requires a new login session (or run: newgrp docker)."
    success "Docker setup complete."
    echo -e "  ${CYAN}Test with:${RESET}  docker run --rm hello-world"
}

# ─── KVM ──────────────────────────────────────────────────────────────────────
setup_kvm() {
    section "KVM / QEMU / libvirt Setup"

    # CPU virtualisation check
    info "Checking hardware virtualisation support..."
    local virt_flags
    virt_flags=$(grep -Ec '(vmx|svm)' /proc/cpuinfo || true)
    if [[ "$virt_flags" -eq 0 ]]; then
        warn "No vmx/svm flags found in /proc/cpuinfo."
        warn "KVM requires Intel VT-x or AMD-V enabled in your UEFI/BIOS."
        if [[ "$NONINTERACTIVE" == true ]]; then
            info "KVM setup skipped (non-interactive)."
            return
        fi
        read -rp "$(echo -e "${YELLOW}Continue anyway? [y/N]: ${RESET}")" cont
        [[ "${cont,,}" != "y" ]] && { info "KVM setup skipped."; return; }
    else
        success "Hardware virtualisation detected (${virt_flags} logical CPUs)."
    fi

    # Check KVM modules
    info "Loading KVM kernel modules..."
    if grep -q 'vendor_id.*Intel' /proc/cpuinfo 2>/dev/null; then
        sudo modprobe kvm_intel || warn "kvm_intel module not loaded — may already be built-in."
    elif grep -q 'vendor_id.*AMD' /proc/cpuinfo 2>/dev/null; then
        sudo modprobe kvm_amd || warn "kvm_amd module not loaded — may already be built-in."
    fi
    sudo modprobe kvm || true

    info "Installing QEMU, libvirt, virt-manager, and bridge tools..."
    sudo pacman -S --needed --noconfirm \
        qemu-full \
        libvirt \
        virt-manager \
        virt-viewer \
        dnsmasq \
        bridge-utils \
        openbsd-netcat \
        dmidecode \
        swtpm \
        edk2-ovmf

    info "Enabling and starting libvirtd..."
    sudo systemctl enable --now libvirtd

    info "Adding ${BOLD}${USER}${RESET} to libvirt and kvm groups..."
    sudo usermod -aG libvirt "$USER"
    sudo usermod -aG kvm    "$USER"

    # Enable default network
    info "Activating libvirt default NAT network..."
    if sudo virsh net-info default &>/dev/null; then
        sudo virsh net-autostart default
        sudo virsh net-start default 2>/dev/null || true
        success "Default NAT network is active."
    else
        warn "Default network not found — you may need to define it manually."
    fi

    if sudo systemctl is-active --quiet libvirtd; then
        success "libvirtd service is running."
    else
        error "libvirtd failed to start. Check: journalctl -xe -u libvirtd"
        return 1
    fi

    success "KVM setup complete."
    echo -e "  ${CYAN}Launch manager:${RESET}  virt-manager"
    echo -e "  ${CYAN}CLI interface:${RESET}   virsh list --all"
}

# ─── LXC ──────────────────────────────────────────────────────────────────────
setup_lxc() {
    section "LXC / LXD Setup"

    info "Installing LXC and LXD..."
    sudo pacman -S --needed --noconfirm lxc

    # LXD is AUR on Arch
    if command -v "$AUR_HELPER" &>/dev/null; then
        info "Installing LXD from AUR via ${AUR_HELPER}..."
        "$AUR_HELPER" -S --needed --noconfirm lxd
    else
        warn "AUR helper unavailable. Skipping LXD (AUR package)."
        warn "Install manually: yay -S lxd"
    fi

    info "Adding ${BOLD}${USER}${RESET} to the lxd and lxc groups..."
    sudo usermod -aG lxd "$USER" 2>/dev/null || true
    sudo usermod -aG lxc "$USER" 2>/dev/null || true

    # Enable cgroup v2 (required for modern LXC/LXD)
    info "Checking cgroup version..."
    if mount | grep -q 'cgroup2'; then
        success "cgroup v2 is already mounted."
    else
        warn "cgroup v2 not detected. You may need to add 'systemd.unified_cgroup_hierarchy=1'"
        warn "to your kernel parameters (e.g., in /etc/default/grub or your bootloader config)."
    fi

    # Enable kernel features for unprivileged containers
    info "Configuring sysctl for unprivileged containers..."
    local sysctl_conf="/etc/sysctl.d/99-arch-virt-setup-lxc.conf"
    if sudo test -e "$sysctl_conf"; then
        warn "Existing sysctl config found at ${sysctl_conf}; preserving current contents."
    else
        sudo tee "$sysctl_conf" > /dev/null <<'EOF'
# LXC unprivileged container support
kernel.unprivileged_userns_clone = 1
net.ipv4.ip_forward = 1
EOF
        success "Created sysctl settings at ${sysctl_conf}."
    fi
    sudo sysctl --system &>/dev/null
    success "sysctl settings applied."

    # Sub-UID/GID ranges for the current user
    info "Ensuring sub-uid/sub-gid mappings for ${USER}..."
    local subid_range=65536
    if ! grep -q "^${USER}:" /etc/subuid 2>/dev/null; then
        local subuid_start
        subuid_start=$(next_subid_start /etc/subuid "$subid_range")
        echo "${USER}:${subuid_start}:${subid_range}" | sudo tee -a /etc/subuid > /dev/null
    fi
    if ! grep -q "^${USER}:" /etc/subgid 2>/dev/null; then
        local subgid_start
        subgid_start=$(next_subid_start /etc/subgid "$subid_range")
        echo "${USER}:${subgid_start}:${subid_range}" | sudo tee -a /etc/subgid > /dev/null
    fi
    success "sub-uid/sub-gid ranges set."

    # Enable and start LXD if installed
    if command -v lxd &>/dev/null; then
        info "Enabling and starting LXD..."
        sudo systemctl enable --now lxd 2>/dev/null || true

        if sudo systemctl is-active --quiet lxd; then
            success "LXD service is running."
        else
            warn "LXD service did not start. Check: journalctl -xe -u lxd"
        fi
    fi

    success "LXC/LXD setup complete."
    echo -e "  ${CYAN}Initialize LXD:${RESET}   sudo lxd init"
    echo -e "  ${CYAN}Launch container:${RESET} lxc launch ubuntu:22.04 mycontainer"
    echo -e "  ${CYAN}List containers:${RESET}  lxc list"
}

# ─── Nix ──────────────────────────────────────────────────────────────────────
setup_nix() {
    section "Nix Package Manager Setup"

    # ── Already installed? ────────────────────────────────────────────────────
    if command -v nix &>/dev/null; then
        NIX_VERSION=$(nix --version 2>/dev/null || echo "unknown")
        success "Nix is already installed: ${BOLD}${NIX_VERSION}${RESET}"
        info "Skipping installer — jumping straight to configuration."
    else
        # ── Determinate Systems installer (recommended for non-NixOS) ─────────
        info "Installing Nix via the Determinate Systems installer..."
        info "This installer handles daemon setup, multi-user mode, and flake"
        info "support automatically — no manual nix.conf tweaks needed."
        echo

        # Requires curl
        if ! command -v curl &>/dev/null; then
            sudo pacman -S --needed --noconfirm curl
        fi

        local installer_script
        installer_script="$(mktemp)"

        curl --proto '=https' --tlsv1.2 -sSf \
            -o "$installer_script" \
            https://install.determinate.systems/nix
        chmod +x "$installer_script"

        info "Downloaded the Nix installer to: ${BOLD}${installer_script}${RESET}"
        info "Review this file before proceeding if desired."

        local confirm_nix_install
        read -r -p "Run the downloaded Nix installer now? [y/N] " confirm_nix_install
        if [[ ! "$confirm_nix_install" =~ ^[Yy]$ ]]; then
            warn "Nix installation cancelled. Installer saved at: ${installer_script}"
            return 0
        fi

        sh "$installer_script" -s -- install --no-confirm

        # Source nix into current session so subsequent steps work
        if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
            # shellcheck source=/dev/null
            source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
        fi

        if command -v nix &>/dev/null; then
            success "Nix installed: $(nix --version)"
        else
            error "Nix binary not found after install. You may need to open a new shell."
            error "Re-run this section after sourcing: /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
        fi
    fi

    # ── nix.conf — enable flakes + nix-command ────────────────────────────────
    # Determinate installer enables these by default, but we ensure it either way.
    local nix_conf="$HOME/.config/nix/nix.conf"
    mkdir -p "$(dirname "$nix_conf")"

    if [[ -f "$nix_conf" ]] \
       && grep -Eq '^\s*experimental-features\s*=.*\bnix-command\b' "$nix_conf" \
       && grep -Eq '^\s*experimental-features\s*=.*\bflakes\b' "$nix_conf"; then
        success "experimental-features already set in ${nix_conf}."
    else
        info "Enabling flakes and nix-command in ${nix_conf}..."
        local nix_conf_tmp
        nix_conf_tmp=$(mktemp)

        if [[ -f "$nix_conf" ]]; then
            awk '
                BEGIN {
                    found = 0
                    updated = 0
                }
                /^[[:space:]]*experimental-features[[:space:]]*=/ {
                    found = 1
                    if (!updated) {
                        line = $0
                        sub(/^[[:space:]]*experimental-features[[:space:]]*=[[:space:]]*/, "", line)
                        sub(/[[:space:]]*#.*/, "", line)

                        count = split(line, parts, /[[:space:]]+/)
                        features = ""
                        has_nix_command = 0
                        has_flakes = 0

                        for (i = 1; i <= count; i++) {
                            if (parts[i] == "") {
                                continue
                            }
                            if (parts[i] == "nix-command") {
                                has_nix_command = 1
                            }
                            if (parts[i] == "flakes") {
                                has_flakes = 1
                            }
                            if (features == "") {
                                features = parts[i]
                            } else {
                                features = features " " parts[i]
                            }
                        }

                        if (!has_nix_command) {
                            if (features == "") {
                                features = "nix-command"
                            } else {
                                features = features " nix-command"
                            }
                        }
                        if (!has_flakes) {
                            if (features == "") {
                                features = "flakes"
                            } else {
                                features = features " flakes"
                            }
                        }

                        print "experimental-features = " features
                        updated = 1
                    }
                    next
                }
                { print }
                END {
                    if (!found) {
                        print ""
                        print "# Enabled by arch-virt-setup.sh"
                        print "experimental-features = nix-command flakes"
                    }
                }
            ' "$nix_conf" > "$nix_conf_tmp"
        else
            cat > "$nix_conf_tmp" <<'EOF'

# Enabled by arch-virt-setup.sh
experimental-features = nix-command flakes
EOF
        fi

        mv "$nix_conf_tmp" "$nix_conf"
        success "flakes + nix-command enabled."
    fi

    # ── direnv + nix-direnv (automatic shell activation per project) ──────────
    echo
    if [[ "$NONINTERACTIVE" == true ]]; then
        install_direnv="y"
    else
        read -rp "$(echo -e "${YELLOW}Install direnv + nix-direnv (auto nix shell on cd)? [Y/n]: ${RESET}")" install_direnv
    fi
    if [[ "${install_direnv,,}" != "n" ]]; then
        info "Installing direnv via pacman..."
        sudo pacman -S --needed --noconfirm direnv

        info "Installing nix-direnv via nix profile..."
        if command -v nix &>/dev/null; then
            nix profile install nixpkgs#nix-direnv
        else
            warn "nix not in PATH yet — install nix-direnv manually later:"
            warn "  nix profile install nixpkgs#nix-direnv"
        fi

        # Hook direnv into the user's shell rc files
        local hooked=false
        for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.config/fish/config.fish"; do
            [[ ! -f "$rc" ]] && continue
            if ! grep -q 'direnv hook' "$rc"; then
                local shell_name
                shell_name=$(basename "$rc" | sed 's/^\.//' | sed 's/rc$//' | sed 's/config\.//')
                echo >> "$rc"
                echo "# direnv hook — added by arch-virt-setup.sh" >> "$rc"
                case "$shell_name" in
                    bash) echo 'eval "$(direnv hook bash)"' >> "$rc" ;;
                    zsh)  echo 'eval "$(direnv hook zsh)"'  >> "$rc" ;;
                    fish) echo 'direnv hook fish | source'  >> "$rc" ;;
                esac
                success "direnv hook added to ${rc}."
                hooked=true
            else
                info "direnv hook already present in ${rc}."
                hooked=true
            fi
        done

        if ! $hooked; then
            warn "No .bashrc / .zshrc / fish config found. Add direnv hook manually:"
            warn '  eval "$(direnv hook bash)"   # or zsh / fish equivalent'
        fi

        # Configure nix-direnv as the nix integration for direnv
        local direnv_lib="$HOME/.config/direnv/lib"
        mkdir -p "$direnv_lib"
        if [[ ! -f "$direnv_lib/nix-direnv.sh" ]]; then
            local nix_direnv_path
            nix_direnv_path=$(nix build --no-link --print-out-paths nixpkgs#nix-direnv 2>/dev/null || true)
            if [[ -n "$nix_direnv_path" ]]; then
                echo "source ${nix_direnv_path}/share/nix-direnv/direnvrc" \
                    > "$direnv_lib/nix-direnv.sh"
                success "nix-direnv integrated with direnv."
            else
                # Fallback: use the nix profile path
                cat > "$direnv_lib/nix-direnv.sh" <<'EOF'
# nix-direnv integration — source the direnvrc from the nix profile
if nix_direnv_path=$(nix build --no-link --print-out-paths nixpkgs#nix-direnv 2>/dev/null); then
  source "${nix_direnv_path}/share/nix-direnv/direnvrc"
fi
EOF
                success "nix-direnv fallback integration written."
            fi
        else
            info "nix-direnv lib already configured."
        fi

        success "direnv + nix-direnv ready."
        echo -e "  ${CYAN}Usage in a project:${RESET}"
        echo -e "    echo 'use flake' > .envrc && direnv allow"
    fi

    # ── Optional extras ───────────────────────────────────────────────────────
    echo
    if [[ "$NONINTERACTIVE" == true ]]; then
        install_nh="n"
    else
        read -rp "$(echo -e "${YELLOW}Install nh (Nix helper / flake runner TUI)? [y/N]: ${RESET}")" install_nh
    fi
    if [[ "${install_nh,,}" == "y" ]]; then
        if command -v nix &>/dev/null; then
            nix profile install nixpkgs#nh
            success "nh installed."
            echo -e "  ${CYAN}Usage:${RESET}  nh os switch / nh home switch"
        else
            warn "nix not in PATH — install nh manually later: nix profile install nixpkgs#nh"
        fi
    fi

    echo
    if [[ "$NONINTERACTIVE" == true ]]; then
        install_ns="n"
    else
        read -rp "$(echo -e "${YELLOW}Install nix-search-cli (search nixpkgs from terminal)? [y/N]: ${RESET}")" install_ns
    fi
    if [[ "${install_ns,,}" == "y" ]]; then
        WANT_NIX_SEARCH_CLI=true
        if [[ -z "${AUR_HELPER:-}" ]] || ! command -v "$AUR_HELPER" &>/dev/null; then
            ensure_aur_helper
        fi
        if [[ -n "${AUR_HELPER:-}" ]] && command -v "$AUR_HELPER" &>/dev/null; then
            "$AUR_HELPER" -S --needed --noconfirm nix-search-cli
            success "nix-search-cli installed."
            echo -e "  ${CYAN}Usage:${RESET}  nix-search python"
        else
            warn "AUR helper unavailable. Install manually: yay -S nix-search-cli"
        fi
    fi

    success "Nix setup complete."
    echo
    echo -e "  ${CYAN}Quick-start a dev shell:${RESET}"
    echo -e "    nix shell nixpkgs#python3 nixpkgs#nodejs"
    echo -e "  ${CYAN}Run a package without installing:${RESET}"
    echo -e "    nix run nixpkgs#cowsay -- 'Hello from Nix'"
    echo -e "  ${CYAN}Init a flake in a project:${RESET}"
    echo -e "    nix flake init"
}

# ─── Summary ──────────────────────────────────────────────────────────────────
print_summary() {
    section "Setup Summary"

    echo -e "${BOLD}What was installed / configured:${RESET}"

    $SETUP_DOCKER && echo -e "  ${GREEN}✔${RESET} Docker + Docker Compose + Docker Buildx"
    $SETUP_KVM    && echo -e "  ${GREEN}✔${RESET} QEMU-Full + libvirt + virt-manager + bridge tools"
    $SETUP_LXC    && echo -e "  ${GREEN}✔${RESET} LXC + LXD (from AUR) + sysctl tweaks + sub-uid mappings"
    $SETUP_NIX    && echo -e "  ${GREEN}✔${RESET} Nix (Determinate) + flakes + nix-command + direnv/nix-direnv"

    echo
    warn "Group changes require a new login session to take effect."
    warn "To apply immediately (per group):"
    $SETUP_DOCKER && echo -e "   ${CYAN}newgrp docker${RESET}"
    $SETUP_KVM    && echo -e "   ${CYAN}newgrp libvirt${RESET}"
    $SETUP_LXC    && echo -e "   ${CYAN}newgrp lxd${RESET}"

    if $SETUP_NIX; then
        echo
        warn "Nix: open a new shell (or source the daemon profile) to use nix commands:"
        echo -e "   ${CYAN}source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh${RESET}"
    fi

    echo
    success "All done! Enjoy your full dev stack. 🚀"
}

# ─── Interactive menu ─────────────────────────────────────────────────────────
interactive_menu() {
    echo -e "\n${BOLD}${BLUE}╔══════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${BLUE}║     Arch Dev Environment Setup Script    ║${RESET}"
    echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════╝${RESET}\n"

    echo -e "What would you like to install?\n"
    echo -e "  ${BOLD}1)${RESET} Docker only"
    echo -e "  ${BOLD}2)${RESET} KVM / QEMU / libvirt only"
    echo -e "  ${BOLD}3)${RESET} LXC / LXD only"
    echo -e "  ${BOLD}4)${RESET} Nix only"
    echo -e "  ${BOLD}5)${RESET} Docker + Nix  ${CYAN}(code dev stack)${RESET}"
    echo -e "  ${BOLD}6)${RESET} KVM + LXC     ${CYAN}(OS exploration stack)${RESET}"
    echo -e "  ${BOLD}7)${RESET} Docker + KVM"
    echo -e "  ${BOLD}8)${RESET} Docker + LXC"
    echo -e "  ${BOLD}9)${RESET} All (Docker + KVM + LXC + Nix)"
    echo -e "  ${BOLD}q)${RESET} Quit\n"

    read -rp "$(echo -e "${YELLOW}Choice [1-9/q]: ${RESET}")" choice

    case "$choice" in
        1) SETUP_DOCKER=true ;;
        2) SETUP_KVM=true ;;
        3) SETUP_LXC=true ;;
        4) SETUP_NIX=true ;;
        5) SETUP_DOCKER=true; SETUP_NIX=true ;;
        6) SETUP_KVM=true;    SETUP_LXC=true ;;
        7) SETUP_DOCKER=true; SETUP_KVM=true ;;
        8) SETUP_DOCKER=true; SETUP_LXC=true ;;
        9) SETUP_DOCKER=true; SETUP_KVM=true; SETUP_LXC=true; SETUP_NIX=true ;;
        q|Q) info "Exiting. Nothing was changed."; exit 0 ;;
        *) die "Invalid choice: $choice" ;;
    esac
}

# ─── Parse CLI flags ──────────────────────────────────────────────────────────
SETUP_DOCKER=false
SETUP_KVM=false
SETUP_LXC=false
SETUP_NIX=false
USE_MENU=true
NONINTERACTIVE=false
WANT_NIX_SEARCH_CLI=false

for arg in "$@"; do
    case "$arg" in
        --docker) SETUP_DOCKER=true; USE_MENU=false; NONINTERACTIVE=true ;;
        --kvm)    SETUP_KVM=true;    USE_MENU=false; NONINTERACTIVE=true ;;
        --lxc)    SETUP_LXC=true;    USE_MENU=false; NONINTERACTIVE=true ;;
        --nix)    SETUP_NIX=true;    USE_MENU=false; NONINTERACTIVE=true ;;
        --all)    SETUP_DOCKER=true; SETUP_KVM=true; SETUP_LXC=true; SETUP_NIX=true; USE_MENU=false; NONINTERACTIVE=true ;;
        --help|-h)
            echo "Usage: $0 [--docker] [--kvm] [--lxc] [--nix] [--all]"
            echo "  No flags: interactive menu"
            exit 0 ;;
        *) die "Unknown flag: $arg. Use --help for usage." ;;
    esac
done

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    check_root
    check_sudo
    check_arch
    check_internet
    detect_distro

    $USE_MENU && interactive_menu

    if ! $SETUP_DOCKER && ! $SETUP_KVM && ! $SETUP_LXC && ! $SETUP_NIX; then
        die "Nothing selected. Use --help for usage."
    fi

    update_system
    if helper_needed; then
        ensure_aur_helper
    fi

    $SETUP_DOCKER && setup_docker
    $SETUP_KVM    && setup_kvm
    $SETUP_LXC    && setup_lxc
    $SETUP_NIX    && setup_nix

    print_summary
}

main
