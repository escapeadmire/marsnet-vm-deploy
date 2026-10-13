#!/usr/bin/env bash

set -Eeuo pipefail

readonly BREW_PREFIX="/home/linuxbrew/.linuxbrew"
readonly TAILSCALE_INSTALL_URL="https://tailscale.com/install.sh"
readonly HOMEBREW_INSTALL_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"

say() {
  printf '\n==> %s\n' "$*"
}

fail() {
  printf '\nError: %s\n' "$*" >&2
  exit 1
}

if [[ "${EUID}" -eq 0 ]]; then
  fail "Run this script as your normal Ubuntu user, not as root. It will use sudo when needed."
fi

if [[ ! -t 0 || ! -t 1 ]]; then
  fail "An interactive terminal is required for Tailscale and OpenCode setup."
fi

if [[ ! -r /etc/os-release ]]; then
  fail "Could not identify this operating system. This script supports Ubuntu."
fi

# shellcheck source=/etc/os-release
source /etc/os-release
if [[ "${ID:-}" != "ubuntu" ]]; then
  fail "This script supports Ubuntu only (detected: ${PRETTY_NAME:-unknown})."
fi

command -v apt-get >/dev/null 2>&1 || fail "apt-get is required."
command -v sudo >/dev/null 2>&1 || fail "sudo is required."
sudo -v || fail "Could not obtain sudo privileges."

say "Installing Homebrew prerequisites"
sudo apt-get update
sudo apt-get install -y build-essential ca-certificates curl file git procps

if ! command -v tailscale >/dev/null 2>&1; then
  say "Downloading the official Tailscale installer"
  tailscale_installer="$(mktemp)"
  trap 'rm -f "${tailscale_installer:-}" "${homebrew_installer:-}"' EXIT
  curl --fail --location --silent --show-error "${TAILSCALE_INSTALL_URL}" --output "${tailscale_installer}"
  sudo sh "${tailscale_installer}"
fi

say "Ensuring Tailscale starts automatically"
sudo systemctl enable --now tailscaled

if ! sudo tailscale ip -4 >/dev/null 2>&1; then
  say "Sign in to Tailscale"
  printf 'Tailscale will print an authentication URL. Open it in your browser and sign in.\n'
  sudo tailscale up

  printf 'Waiting for this VM to join your tailnet'
  connected=false
  for _ in {1..120}; do
    if sudo tailscale ip -4 >/dev/null 2>&1; then
      connected=true
      break
    fi
    printf '.'
    sleep 5
  done
  printf '\n'
  [[ "${connected}" == true ]] || fail "Tailscale login was not detected after 10 minutes. Rerun this script after signing in."
else
  say "Tailscale is already connected"
fi

say "Enabling Tailscale SSH"
sudo tailscale set --ssh

if [[ ! -x "${BREW_PREFIX}/bin/brew" ]] && ! command -v brew >/dev/null 2>&1; then
  say "Downloading the official Homebrew installer"
  homebrew_installer="$(mktemp)"
  trap 'rm -f "${tailscale_installer:-}" "${homebrew_installer:-}"' EXIT
  curl --fail --location --silent --show-error "${HOMEBREW_INSTALL_URL}" --output "${homebrew_installer}"
  NONINTERACTIVE=1 /bin/bash "${homebrew_installer}"
fi

if [[ -x "${BREW_PREFIX}/bin/brew" ]]; then
  brew_bin="${BREW_PREFIX}/bin/brew"
elif command -v brew >/dev/null 2>&1; then
  brew_bin="$(command -v brew)"
else
  fail "Homebrew installation finished, but the brew command was not found."
fi

eval "$("${brew_bin}" shellenv)"

shell_name="${SHELL##*/}"
case "${shell_name}" in
  zsh) shell_config="${HOME}/.zshrc" ;;
  *) shell_config="${HOME}/.bashrc" ;;
esac
brew_shellenv_line="eval \"\$(${brew_bin} shellenv)\""
if ! grep -Fqx -- "${brew_shellenv_line}" "${shell_config}" 2>/dev/null; then
  printf '\n%s\n' "${brew_shellenv_line}" >>"${shell_config}"
fi

say "Installing GitHub CLI and OpenCode with Homebrew"
brew install gh
brew install anomalyco/tap/opencode

say "Installation complete"
printf 'Homebrew and gh are ready. Homebrew PATH setup was added to %s.\n' "${shell_config}"
printf 'Tailscale SSH is enabled; tailnet policy must permit your SSH access. After verifying access, restrict or close Azure port 22.\n'
printf 'OpenCode is starting. In its interface, use /connect to authenticate with your provider.\n\n'

opencode
