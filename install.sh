#!/usr/bin/env bash

set -u

resolve_user_home() {
  local user_name="$1"

  if [[ "$(uname -s)" == "Darwin" ]] && command -v dscl >/dev/null 2>&1; then
    dscl . -read "/Users/$user_name" NFSHomeDirectory 2>/dev/null | awk '{print $2}'
    return
  fi

  if command -v getent >/dev/null 2>&1; then
    getent passwd "$user_name" | cut -d: -f6
    return
  fi

  eval "printf '%s\n' \"~$user_name\""
}

if [[ "$(id -u)" -eq 0 && -n "${SUDO_USER:-}" ]]; then
  ORIGINAL_USER="$SUDO_USER"
  ORIGINAL_HOME="$(resolve_user_home "$ORIGINAL_USER")"

  if [[ -n "$ORIGINAL_HOME" ]]; then
    echo "Re-running install.sh as $ORIGINAL_USER so dotfiles are installed into $ORIGINAL_HOME"
    exec sudo -H -u "$ORIGINAL_USER" \
      env -u SUDO_USER -u SUDO_UID -u SUDO_GID HOME="$ORIGINAL_HOME" PATH="$PATH" \
      bash "$0" "$@"
  fi
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS_NAME="$(uname -s)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$HOME/.dotfile-backups/$TIMESTAMP"
PRIVATE_EXAMPLE="$REPO_ROOT/zsh/zshrc.d/90-private.example.zsh"
PRIVATE_LOCAL="$REPO_ROOT/zsh/zshrc.d/99-private.local.zsh"

declare -a DONE_MESSAGES=()
declare -a SKIPPED_MESSAGES=()
declare -a WARN_MESSAGES=()

log_done() {
  DONE_MESSAGES+=("$1")
}

log_skip() {
  SKIPPED_MESSAGES+=("$1")
}

log_warn() {
  WARN_MESSAGES+=("$1")
}

warn_missing_command() {
  local command_name="$1"
  local message="$2"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    log_warn "$message"
  fi
}

ensure_dir() {
  mkdir -p "$1"
}

load_cargo_env() {
  if [[ -f "$HOME/.cargo/env" ]]; then
    # shellcheck disable=SC1090
    source "$HOME/.cargo/env"
  fi
}

backup_path() {
  local target="$1"
  local relative
  relative="${target#"$HOME"/}"
  relative="${relative#/}"
  ensure_dir "$BACKUP_DIR/$(dirname "$relative")"
  mv "$target" "$BACKUP_DIR/$relative"
  log_done "Backed up $target to $BACKUP_DIR/$relative"
}

ensure_link() {
  local source_path="$1"
  local target_path="$2"

  ensure_dir "$(dirname "$target_path")"

  if [[ -L "$target_path" ]]; then
    if [[ "$(readlink "$target_path")" == "$source_path" ]]; then
      log_skip "Symlink already correct: $target_path"
      return
    fi
    backup_path "$target_path"
  elif [[ -e "$target_path" ]]; then
    backup_path "$target_path"
  fi

  ln -s "$source_path" "$target_path"
  log_done "Linked $target_path -> $source_path"
}

copy_private_template() {
  if [[ -f "$PRIVATE_LOCAL" ]]; then
    log_skip "Private zsh file already exists: $PRIVATE_LOCAL"
    return
  fi

  cp "$PRIVATE_EXAMPLE" "$PRIVATE_LOCAL"
  log_done "Created private zsh template copy: $PRIVATE_LOCAL"
}

brew_install_package() {
  local package="$1"

  if brew list --versions "$package" >/dev/null 2>&1; then
    log_skip "brew package already installed: $package"
    return
  fi

  if brew install "$package"; then
    log_done "Installed brew package: $package"
  else
    log_warn "Failed to install brew package: $package"
  fi
}

apt_install_package() {
  local package="$1"
  shift

  if command -v "$@" >/dev/null 2>&1; then
    log_skip "Command already available: $*"
    return
  fi

  if "$APT_RUNNER" apt-get install -y "$package"; then
    log_done "Installed apt package: $package"
  else
    log_warn "Failed to install apt package: $package"
  fi
}

install_rust() {
  load_cargo_env

  if command -v cargo >/dev/null 2>&1; then
    log_skip "Rust toolchain already available"
    return
  fi

  if ! command -v curl >/dev/null 2>&1; then
    log_warn "curl is required to install rustup automatically"
    return
  fi

  if curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; then
    load_cargo_env
    export PATH="$HOME/.cargo/bin:$PATH"
    log_done "Installed rustup and cargo"
  else
    log_warn "Failed to install rustup automatically"
  fi
}

install_yazi() {
  load_cargo_env

  if command -v yazi >/dev/null 2>&1; then
    log_skip "yazi already available"
    return
  fi

  if ! command -v cargo >/dev/null 2>&1; then
    log_warn "cargo is unavailable, skipped Yazi installation"
    return
  fi

  if cargo install --force yazi-build; then
    if command -v yazi >/dev/null 2>&1 && command -v ya >/dev/null 2>&1; then
      log_done "Installed Yazi with cargo install --force yazi-build"
    else
      log_warn "yazi-build completed but yazi/ya were not found on PATH; check $HOME/.cargo/bin"
    fi
  else
    log_warn "Failed to install Yazi with cargo install --force yazi-build; ensure make and gcc are installed"
  fi
}

install_oh_my_zsh() {
  if [[ -s "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]]; then
    log_skip "Oh My Zsh already installed"
    return
  fi

  if ! command -v curl >/dev/null 2>&1; then
    log_warn "curl is unavailable, skipped Oh My Zsh installation"
    return
  fi

  if RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; then
    log_done "Installed Oh My Zsh"
  else
    log_warn "Failed to install Oh My Zsh automatically"
  fi
}

install_oh_my_zsh_plugin() {
  local plugin_name="$1"
  local plugin_repo="$2"
  local zsh_custom_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  local plugin_dir="$zsh_custom_dir/plugins/$plugin_name"

  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    log_warn "Oh My Zsh is unavailable, skipped plugin: $plugin_name"
    return
  fi

  if [[ -d "$plugin_dir" ]]; then
    log_skip "Oh My Zsh plugin already installed: $plugin_name"
    return
  fi

  if ! command -v git >/dev/null 2>&1; then
    log_warn "git is unavailable, skipped Oh My Zsh plugin: $plugin_name"
    return
  fi

  ensure_dir "$zsh_custom_dir/plugins"

  if git clone --depth=1 "$plugin_repo" "$plugin_dir"; then
    log_done "Installed Oh My Zsh plugin: $plugin_name"
  else
    log_warn "Failed to install Oh My Zsh plugin: $plugin_name"
  fi
}

install_oh_my_zsh_plugins() {
  install_oh_my_zsh_plugin "zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions"
  install_oh_my_zsh_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting"
}

install_yazi_support_packages_macos() {
  brew_install_package jq
  brew_install_package ffmpeg
  brew_install_package p7zip
  brew_install_package poppler
  brew_install_package imagemagick
}

install_yazi_support_packages_linux() {
  apt_install_package file file
  apt_install_package jq jq
  apt_install_package ffmpeg ffmpeg
  apt_install_package p7zip-full 7z
  apt_install_package poppler-utils pdfinfo
  apt_install_package imagemagick identify
  apt_install_package build-essential gcc
}

current_login_shell() {
  local current_user
  current_user="$(id -un)"

  if [[ "$OS_NAME" == "Darwin" ]] && command -v dscl >/dev/null 2>&1; then
    dscl . -read "/Users/$current_user" UserShell 2>/dev/null | awk '{print $2}'
    return
  fi

  if [[ "$OS_NAME" == "Linux" ]] && command -v getent >/dev/null 2>&1; then
    getent passwd "$current_user" | cut -d: -f7
    return
  fi

  printf '%s\n' "${SHELL:-}"
}

switch_default_shell() {
  local zsh_path
  local login_shell
  zsh_path="$(command -v zsh || true)"
  login_shell="$(current_login_shell)"

  if [[ -z "$zsh_path" ]]; then
    log_warn "zsh is not installed, skipped default shell change"
    return
  fi

  if [[ "$(basename "$login_shell")" == "zsh" ]]; then
    log_skip "Login shell already uses zsh: $login_shell"
    return
  fi

  if ! command -v chsh >/dev/null 2>&1; then
    log_warn "chsh is unavailable, change your default shell manually to $zsh_path"
    return
  fi

  if chsh -s "$zsh_path"; then
    log_done "Changed default shell to $zsh_path"
  else
    log_warn "Failed to change default shell automatically; run chsh -s $zsh_path manually if needed"
  fi
}

install_packages_macos() {
  if ! command -v brew >/dev/null 2>&1; then
    log_warn "Homebrew not found; install zsh tmux git curl ripgrep fzf neovim manually if needed"
    return
  fi

  brew_install_package zsh
  brew_install_package tmux
  brew_install_package git
  brew_install_package curl
  brew_install_package ripgrep
  brew_install_package fzf
  brew_install_package neovim
  install_yazi_support_packages_macos
}

install_packages_linux() {
  if ! command -v apt-get >/dev/null 2>&1; then
    log_warn "apt-get not found; install zsh tmux git curl ripgrep fzf neovim manually if needed"
    return
  fi

  if command -v sudo >/dev/null 2>&1; then
    APT_RUNNER="sudo"
  elif [[ "$(id -u)" -eq 0 ]]; then
    APT_RUNNER=""
  else
    log_warn "sudo not available; skipped apt installs for zsh tmux git curl ripgrep fzf neovim"
    return
  fi

  if [[ -n "$APT_RUNNER" ]]; then
    if "$APT_RUNNER" apt-get update; then
      log_done "Ran apt-get update"
    else
      log_warn "apt-get update failed"
    fi
  else
    if apt-get update; then
      log_done "Ran apt-get update"
    else
      log_warn "apt-get update failed"
    fi
  fi

  if [[ -n "$APT_RUNNER" ]]; then
    apt_install_package zsh zsh
    apt_install_package tmux tmux
    apt_install_package git git
    apt_install_package curl curl
    apt_install_package ripgrep rg
    apt_install_package fzf fzf
    apt_install_package neovim nvim
    install_yazi_support_packages_linux
  else
    APT_RUNNER="env"
    apt_install_package zsh zsh
    apt_install_package tmux tmux
    apt_install_package git git
    apt_install_package curl curl
    apt_install_package ripgrep rg
    apt_install_package fzf fzf
    apt_install_package neovim nvim
    install_yazi_support_packages_linux
  fi
}

check_runtime_tools() {
  warn_missing_command "nvim" "Neovim is still unavailable; this LazyVim config will not work until nvim is installed"
  warn_missing_command "yazi" "Yazi is still unavailable; install it manually or ensure $HOME/.cargo/bin is on PATH"
  warn_missing_command "file" "The 'file' utility is unavailable; Yazi file type detection will be reduced"
  warn_missing_command "jq" "jq is unavailable; some Yazi JSON-based integrations may not work"
  warn_missing_command "ffmpeg" "ffmpeg is unavailable; Yazi media previews may be limited"
  warn_missing_command "7z" "7z is unavailable; Yazi archive handling may be limited"
  warn_missing_command "pdfinfo" "poppler-utils is unavailable; Yazi PDF metadata/preview helpers may be limited"
}

print_summary() {
  echo
  echo "Summary"
  echo "======="

  if ((${#DONE_MESSAGES[@]} > 0)); then
    echo
    echo "Completed:"
    printf '  - %s\n' "${DONE_MESSAGES[@]}"
  fi

  if ((${#SKIPPED_MESSAGES[@]} > 0)); then
    echo
    echo "Skipped:"
    printf '  - %s\n' "${SKIPPED_MESSAGES[@]}"
  fi

  if ((${#WARN_MESSAGES[@]} > 0)); then
    echo
    echo "Warnings:"
    printf '  - %s\n' "${WARN_MESSAGES[@]}"
  fi
}

main() {
  ensure_dir "$HOME/.config"
  ensure_dir "$HOME/.dotfile-backups"

  case "$OS_NAME" in
    Darwin)
      install_packages_macos
      ;;
    Linux)
      install_packages_linux
      ;;
    *)
      log_warn "Unsupported OS: $OS_NAME"
      ;;
  esac

  install_rust
  install_yazi
  install_oh_my_zsh
  install_oh_my_zsh_plugins
  copy_private_template

  ensure_link "$REPO_ROOT/zsh/.zshrc" "$HOME/.zshrc"
  ensure_link "$REPO_ROOT/tmux/.tmux.conf" "$HOME/.tmux.conf"

  if [[ -f "$REPO_ROOT/git/.gitconfig" ]]; then
    ensure_link "$REPO_ROOT/git/.gitconfig" "$HOME/.gitconfig"
  else
    log_skip "git/.gitconfig is absent, skipped gitconfig management"
  fi

  ensure_link "$REPO_ROOT/nvim" "$HOME/.config/nvim"
  ensure_link "$REPO_ROOT/yazi" "$HOME/.config/yazi"

  check_runtime_tools
  switch_default_shell
  print_summary
}

main "$@"
