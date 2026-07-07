#!/usr/bin/env bash

set -u

print_usage() {
  cat <<'USAGE'
Usage: ./init.sh [options]

Options:
  --link-only       Only generate dotfiles and symlinks; skip installs and chsh
  --no-packages     Skip OS package manager installs
  --no-user-tools   Skip user-local tool installs (Rust, Bun, Yazi, Oh My Zsh)
  --upgrade-neovim  Install the latest official Neovim release
  --no-chsh         Do not change the login shell
  -h, --help        Show this help
USAGE
}

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
    echo "Re-running init.sh as $ORIGINAL_USER so dotfiles are installed into $ORIGINAL_HOME"
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
ZSH_MANAGED_BEGIN="# >>> dotfile managed block >>>"
ZSH_MANAGED_END="# <<< dotfile managed block <<<"
ZSH_LOCAL_BEGIN="# >>> dotfile local block >>>"
ZSH_LOCAL_END="# <<< dotfile local block <<<"
SKIP_PACKAGE_INSTALLS=0
SKIP_USER_TOOL_INSTALLS=0
SKIP_CHSH=0
FORCE_NEOVIM_UPGRADE=0
APT_RUNNER=""

declare -a DONE_MESSAGES=()
declare -a SKIPPED_MESSAGES=()
declare -a WARN_MESSAGES=()
declare -a OH_MY_ZSH_CUSTOM_PLUGINS=("zsh-autosuggestions" "zsh-syntax-highlighting")

parse_args() {
  while (($# > 0)); do
    case "$1" in
      --link-only)
        SKIP_PACKAGE_INSTALLS=1
        SKIP_USER_TOOL_INSTALLS=1
        SKIP_CHSH=1
        ;;
      --no-packages)
        SKIP_PACKAGE_INSTALLS=1
        ;;
      --no-user-tools)
        SKIP_USER_TOOL_INSTALLS=1
        ;;
      --upgrade-neovim)
        FORCE_NEOVIM_UPGRADE=1
        ;;
      --no-chsh)
        SKIP_CHSH=1
        ;;
      -h | --help)
        print_usage
        exit 0
        ;;
      *)
        printf 'Unknown option: %s\n\n' "$1" >&2
        print_usage >&2
        exit 2
        ;;
    esac
    shift
  done
}

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

command_version_ge() {
  local current_version="$1"
  local minimum_version="$2"
  local current_major current_minor current_patch
  local minimum_major minimum_minor minimum_patch

  if [[ -z "$current_version" ]]; then
    return 1
  fi

  parse_semver "$current_version" current_major current_minor current_patch
  parse_semver "$minimum_version" minimum_major minimum_minor minimum_patch

  if ((current_major != minimum_major)); then
    ((current_major > minimum_major))
    return
  fi

  if ((current_minor != minimum_minor)); then
    ((current_minor > minimum_minor))
    return
  fi

  ((current_patch >= minimum_patch))
}

parse_semver() {
  local version="$1"
  local major_name="$2"
  local minor_name="$3"
  local patch_name="$4"
  local major minor patch

  version="${version#v}"
  version="${version%%[-+~_]*}"

  IFS=. read -r major minor patch _ <<<"$version"

  major="$(numeric_version_part "$major")"
  minor="$(numeric_version_part "$minor")"
  patch="$(numeric_version_part "$patch")"

  printf -v "$major_name" '%d' "$((10#$major))"
  printf -v "$minor_name" '%d' "$((10#$minor))"
  printf -v "$patch_name" '%d' "$((10#$patch))"
}

numeric_version_part() {
  local value="${1:-0}"

  value="${value%%[!0-9]*}"
  if [[ -z "$value" ]]; then
    value=0
  fi

  printf '%s\n' "$value"
}

get_nvim_version() {
  if ! command -v nvim >/dev/null 2>&1; then
    return 1
  fi

  nvim --version 2>/dev/null | awk 'NR==1 { sub(/^v/, "", $2); print $2 }'
}

ensure_dir() {
  mkdir -p "$1"
}

prepend_path_if_dir() {
  local dir="$1"

  [[ -d "$dir" ]] || return

  case ":$PATH:" in
    *":$dir:"*)
      ;;
    *)
      export PATH="$dir:$PATH"
      ;;
  esac
}

load_cargo_env() {
  if [[ -f "$HOME/.cargo/env" ]]; then
    # shellcheck disable=SC1091
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

file_has_line() {
  local file_path="$1"
  local needle="$2"

  [[ -f "$file_path" ]] && grep -Fqx "$needle" "$file_path"
}

extract_marked_block() {
  local file_path="$1"
  local begin_marker="$2"
  local end_marker="$3"

  awk -v begin="$begin_marker" -v end="$end_marker" '
    $0 == begin { in_block=1; next }
    $0 == end { exit }
    in_block { print }
  ' "$file_path"
}

local_zsh_seed_source() {
  local target_path="$HOME/.zshrc"

  if file_has_line "$target_path" "$ZSH_LOCAL_BEGIN"; then
    printf '%s\n' "existing"
    return
  fi

  if [[ -f "$PRIVATE_LOCAL" ]]; then
    printf '%s\n' "private"
    return
  fi

  printf '%s\n' "example"
}

initial_local_zsh_content() {
  local seed_source="$1"
  local target_path="$HOME/.zshrc"

  case "$seed_source" in
    existing)
      extract_marked_block "$target_path" "$ZSH_LOCAL_BEGIN" "$ZSH_LOCAL_END"
      ;;
    private)
      cat "$PRIVATE_LOCAL"
      ;;
    *)
      cat "$PRIVATE_EXAMPLE"
      ;;
  esac
}

write_generated_zshrc() {
  local output_path="$1"
  local local_block_content="$2"
  local zsh_file
  local file_name

  {
    printf '%s\n' "$ZSH_MANAGED_BEGIN"
    printf '%s\n' "# Generated by $REPO_ROOT/init.sh."
    printf '%s\n' "# Re-run ./init.sh to refresh the managed block."
    printf '%s\n' "# Edit the local block below for machine-specific values."
    printf '\n'

    for zsh_file in "$REPO_ROOT"/zsh/zshrc.d/*.zsh; do
      file_name="$(basename "$zsh_file")"

      case "$file_name" in
        90-private.example.zsh | *.local.zsh)
          continue
          ;;
      esac

      printf '%s\n' "# --- $file_name ---"
      cat "$zsh_file"
      printf '\n'
    done

    printf '%s\n' "$ZSH_MANAGED_END"
    printf '\n'
    printf '%s\n' "$ZSH_LOCAL_BEGIN"
    printf '%s\n' "# Add machine-only exports, tokens, private paths, and aliases here."
    printf '%s\n' "# This block is preserved when the installer regenerates ~/.zshrc."

    if [[ -n "$local_block_content" ]]; then
      printf '\n%s' "$local_block_content"
      [[ "$local_block_content" == *$'\n' ]] || printf '\n'
    else
      printf '\n'
    fi

    printf '%s\n' "$ZSH_LOCAL_END"
  } >"$output_path"
}

ensure_generated_zshrc() {
  local target_path="$HOME/.zshrc"
  local tmp_file
  local local_block_content
  local seed_source

  if file_has_line "$target_path" "$ZSH_MANAGED_BEGIN"; then
    log_skip "Updating generated zshrc in place: $target_path"
  elif [[ -L "$target_path" || -e "$target_path" ]]; then
    backup_path "$target_path"
  fi

  seed_source="$(local_zsh_seed_source)"
  local_block_content="$(initial_local_zsh_content "$seed_source")"
  tmp_file="$(mktemp)"
  write_generated_zshrc "$tmp_file" "$local_block_content"
  mv "$tmp_file" "$target_path"

  case "$seed_source" in
    existing)
      log_done "Generated $target_path and preserved the existing local block"
      ;;
    private)
      log_done "Generated $target_path and seeded the local block from $PRIVATE_LOCAL"
      ;;
    *)
      log_done "Generated $target_path and seeded the local block from $PRIVATE_EXAMPLE"
      ;;
  esac
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

  if run_apt_get install -y "$package"; then
    log_done "Installed apt package: $package"
  else
    log_warn "Failed to install apt package: $package"
  fi
}

run_apt_get() {
  if [[ -n "$APT_RUNNER" ]]; then
    "$APT_RUNNER" apt-get "$@"
  else
    apt-get "$@"
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

install_bun() {
  prepend_path_if_dir "$HOME/.bun/bin"

  if command -v bun >/dev/null 2>&1; then
    log_skip "bun already available"
    return
  fi

  if ! command -v curl >/dev/null 2>&1; then
    log_warn "curl is unavailable, skipped bun installation"
    return
  fi

  if ! command -v unzip >/dev/null 2>&1; then
    log_warn "unzip is unavailable, skipped bun installation"
    return
  fi

  if curl -fsSL https://bun.sh/install | bash; then
    export PATH="$HOME/.bun/bin:$PATH"
    log_done "Installed bun"
  else
    log_warn "Failed to install bun automatically"
  fi
}

install_uv() {
  prepend_path_if_dir "$HOME/.local/bin"

  if command -v uv >/dev/null 2>&1; then
    log_skip "uv already available"
    return
  fi

  if ! command -v curl >/dev/null 2>&1; then
    log_warn "curl is unavailable, skipped uv installation"
    return
  fi

  ensure_dir "$HOME/.local/bin"

  if curl -LsSf https://astral.sh/uv/install.sh | env UV_UNMANAGED_INSTALL="$HOME/.local/bin" sh; then
    export PATH="$HOME/.local/bin:$PATH"
    log_done "Installed uv to ~/.local/bin"
  else
    log_warn "Failed to install uv automatically"
  fi
}

install_python_tools() {
  if command -v ruff >/dev/null 2>&1; then
    log_skip "ruff already available"
    return
  fi

  if ! command -v uv >/dev/null 2>&1; then
    log_warn "uv is unavailable, skipped ruff installation"
    return
  fi

  if uv tool install ruff; then
    log_done "Installed ruff with uv tool install"
  else
    log_warn "Failed to install ruff with uv"
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
  local plugin_dir
  plugin_dir="$(oh_my_zsh_custom_plugin_dir "$plugin_name")"

  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    log_warn "Oh My Zsh is unavailable, skipped plugin: $plugin_name"
    return
  fi

  if oh_my_zsh_plugin_available "$plugin_name"; then
    log_skip "Oh My Zsh plugin already installed: $plugin_name"
    return
  fi

  if ! command -v git >/dev/null 2>&1; then
    log_warn "git is unavailable, skipped Oh My Zsh plugin: $plugin_name"
    return
  fi

  ensure_dir "$(dirname "$plugin_dir")"

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

oh_my_zsh_custom_plugin_dir() {
  local plugin_name="$1"
  local zsh_custom_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

  printf '%s\n' "$zsh_custom_dir/plugins/$plugin_name"
}

oh_my_zsh_plugin_available() {
  local plugin_name="$1"
  local custom_plugin_dir
  custom_plugin_dir="$(oh_my_zsh_custom_plugin_dir "$plugin_name")"

  [[ -d "$custom_plugin_dir" || -d "$HOME/.oh-my-zsh/plugins/$plugin_name" ]]
}

verify_oh_my_zsh_plugins() {
  local plugin_name

  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    return
  fi

  for plugin_name in "${OH_MY_ZSH_CUSTOM_PLUGINS[@]}"; do
    if ! oh_my_zsh_plugin_available "$plugin_name"; then
      log_warn "Oh My Zsh plugin missing: $plugin_name; rerun ./init.sh or install it under ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/"
    fi
  done
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
  apt_install_package unzip unzip
  apt_install_package ffmpeg ffmpeg
  apt_install_package p7zip-full 7z
  apt_install_package poppler-utils pdfinfo
  apt_install_package imagemagick identify
  apt_install_package build-essential gcc
}

install_official_neovim_linux() {
  local arch
  local archive_name
  local download_url
  local install_root="$HOME/.local/opt"
  local install_dir
  local tmp_dir

  if ! command -v curl >/dev/null 2>&1; then
    log_warn "curl is unavailable, skipped official Neovim download fallback"
    return
  fi

  if ! command -v tar >/dev/null 2>&1; then
    log_warn "tar is unavailable, skipped official Neovim download fallback"
    return
  fi

  case "$(uname -m)" in
    x86_64 | amd64)
      arch="x86_64"
      ;;
    aarch64 | arm64)
      arch="arm64"
      ;;
    *)
      log_warn "Unsupported Linux architecture for official Neovim fallback: $(uname -m)"
      return
      ;;
  esac

  archive_name="nvim-linux-${arch}.tar.gz"
  download_url="https://github.com/neovim/neovim/releases/latest/download/${archive_name}"
  install_dir="$install_root/nvim-linux-${arch}"
  tmp_dir="$(mktemp -d)"

  ensure_dir "$install_root"

  if curl -fL "$download_url" -o "$tmp_dir/$archive_name"; then
    rm -rf "$install_dir"
    if tar -C "$install_root" -xzf "$tmp_dir/$archive_name"; then
      ensure_dir "$HOME/.local/bin"
      ln -sfn "$install_dir/bin/nvim" "$HOME/.local/bin/nvim"
      log_done "Installed official Neovim tarball to $install_dir"
    else
      log_warn "Failed to extract official Neovim tarball"
    fi
  else
    log_warn "Failed to download official Neovim tarball from $download_url"
  fi

  rm -rf "$tmp_dir"
}

upgrade_neovim_macos() {
  if ! command -v brew >/dev/null 2>&1; then
    log_warn "Homebrew not found; cannot upgrade Neovim automatically on macOS"
    return
  fi

  if brew list --versions neovim >/dev/null 2>&1; then
    if brew upgrade neovim; then
      log_done "Upgraded Neovim with Homebrew"
    else
      log_warn "Failed to upgrade Neovim with Homebrew"
    fi
  elif brew install neovim; then
    log_done "Installed Neovim with Homebrew"
  else
    log_warn "Failed to install Neovim with Homebrew"
  fi
}

ensure_usable_neovim() {
  local nvim_version
  nvim_version="$(get_nvim_version || true)"

  if ((FORCE_NEOVIM_UPGRADE)); then
    case "$OS_NAME" in
      Linux)
        install_official_neovim_linux
        ;;
      Darwin)
        upgrade_neovim_macos
        ;;
      *)
        log_warn "Unsupported OS for Neovim upgrade: $OS_NAME"
        ;;
    esac
    return
  fi

  if command_version_ge "$nvim_version" "0.8.0"; then
    log_skip "Neovim version is usable: ${nvim_version}"
    return
  fi

  if [[ "$OS_NAME" == "Linux" ]]; then
    if [[ -n "$nvim_version" ]]; then
      log_warn "System Neovim is too old for LazyVim (${nvim_version} < 0.8.0); installing official Neovim tarball"
    else
      log_warn "Neovim is unavailable after package installation; installing official Neovim tarball"
    fi
    install_official_neovim_linux
    return
  fi

  if [[ -n "$nvim_version" ]]; then
    log_warn "Neovim is installed but too old for LazyVim: ${nvim_version}"
  fi
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

  if ((SKIP_CHSH)); then
    log_skip "Default shell change skipped by option"
    return
  fi

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
  if ((SKIP_PACKAGE_INSTALLS)); then
    log_skip "Package installation skipped by option"
    return
  fi

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
  if ((SKIP_PACKAGE_INSTALLS)); then
    log_skip "Package installation skipped by option"
    return
  fi

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

  if run_apt_get update; then
    log_done "Ran apt-get update"
  else
    log_warn "apt-get update failed"
  fi

  apt_install_package zsh zsh
  apt_install_package tmux tmux
  apt_install_package git git
  apt_install_package curl curl
  apt_install_package ripgrep rg
  apt_install_package fzf fzf
  apt_install_package neovim nvim
  install_yazi_support_packages_linux
}

check_runtime_tools() {
  warn_missing_command "zsh" "zsh is unavailable; the generated ~/.zshrc cannot be used as a login shell"
  warn_missing_command "tmux" "tmux is unavailable; ~/.tmux.conf was linked but tmux cannot run"
  warn_missing_command "git" "git is unavailable; future plugin and repository operations will fail"
  warn_missing_command "curl" "curl is unavailable; network installers cannot run"
  warn_missing_command "rg" "ripgrep is unavailable; search workflows will be reduced"
  warn_missing_command "fzf" "fzf is unavailable; fuzzy finder integrations will be reduced"
  warn_missing_command "bun" "bun is unavailable; Claude/Codex hook commands that use bun will fail"
  warn_missing_command "node" "node compatibility shim is unavailable; rerun ./init.sh after installing bun"
  warn_missing_command "npm" "npm compatibility shim is unavailable; Mason cannot install npm-based Neovim language servers"
  warn_missing_command "npx" "npx compatibility shim is unavailable; npm-style package execution will not use bun automatically"
  warn_missing_command "uv" "uv is unavailable; Python CLI tooling such as ruff will not be managed automatically"
  warn_missing_command "ruff" "ruff is unavailable; Python linting, formatting, and ruff LSP will not work"
  warn_missing_command "nvim" "Neovim is still unavailable; this LazyVim config will not work until nvim is installed"
  warn_missing_command "yazi" "Yazi is still unavailable; install it manually or ensure $HOME/.cargo/bin is on PATH"
  warn_missing_command "file" "The 'file' utility is unavailable; Yazi file type detection will be reduced"
  warn_missing_command "jq" "jq is unavailable; some Yazi JSON-based integrations may not work"
  warn_missing_command "ffmpeg" "ffmpeg is unavailable; Yazi media previews may be limited"
  warn_missing_command "7z" "7z is unavailable; Yazi archive handling may be limited"
  warn_missing_command "pdfinfo" "poppler-utils is unavailable; Yazi PDF metadata/preview helpers may be limited"
}

install_executable_shim() {
  local target_path="$1"
  local description="$2"
  local tmp_file

  tmp_file="$(mktemp)"
  cat >"$tmp_file"
  chmod +x "$tmp_file"

  if [[ -f "$target_path" ]] && cmp -s "$tmp_file" "$target_path"; then
    rm -f "$tmp_file"
    log_skip "$description already current"
    return
  fi

  if [[ -L "$target_path" ]]; then
    rm -f "$target_path"
  elif [[ -e "$target_path" ]]; then
    backup_path "$target_path"
  fi

  mv "$tmp_file" "$target_path"
  log_done "$description"
}

ensure_bun_node_shims() {
  local bun_bin="$HOME/.bun/bin/bun"
  local shim_name
  local shim_path
  local shim_description

  prepend_path_if_dir "$HOME/.bun/bin"

  if [[ ! -x "$bun_bin" ]]; then
    return
  fi

  for shim_name in node npm npx yarn yarnpkg pnpm pnpx corepack; do
    shim_path="$HOME/.bun/bin/$shim_name"
    shim_description="Installed Bun compatibility shim: $shim_name"

    install_executable_shim "$shim_path" "$shim_description" <<'SHIM'
#!/usr/bin/env bash
set -euo pipefail

BUN_BIN="${BUN_INSTALL:-$HOME/.bun}/bin/bun"
if [[ ! -x "$BUN_BIN" ]]; then
  BUN_BIN="$(command -v bun 2>/dev/null || true)"
fi

if [[ -z "${BUN_BIN:-}" || ! -x "$BUN_BIN" ]]; then
  printf 'bun compatibility shim: bun not found\n' >&2
  exit 127
fi

node_version() {
  "$BUN_BIN" -e 'process.stdout.write(process.version + "\n")'
}

node_version_without_prefix() {
  node_version | sed 's/^v//'
}

bun_version() {
  "$BUN_BIN" --version
}

npm_version() {
  printf '10.0.0\n'
}

yarn_version() {
  printf '1.22.22\n'
}

pnpm_version() {
  printf '10.0.0\n'
}

corepack_version() {
  printf '0.31.0\n'
}

ensure_package_json() {
  if [[ ! -f package.json ]]; then
    printf '{"name":"bun-managed-package","private":true}\n' >package.json
  fi
}

translate_package_args() {
  translated_args=()

  while (($# > 0)); do
    case "$1" in
      --global-style | --legacy-peer-deps | --strict-peer-deps | --prefer-dedupe | --no-audit | --no-fund)
        ;;
      --install-strategy=* | --audit=* | --fund=* | --progress=* | --package-lock=* | --save-package-lock=*)
        ;;
      --save-dev)
        translated_args+=("--dev")
        ;;
      --save-exact)
        translated_args+=("--exact")
        ;;
      --location=global)
        translated_args+=("--global")
        ;;
      --)
        shift
        while (($# > 0)); do
          translated_args+=("$1")
          shift
        done
        break
        ;;
      *)
        translated_args+=("$1")
        ;;
    esac
    shift
  done
}

run_bunx() {
  local bunx_args=()

  if [[ $# -eq 0 ]]; then
    exec "$BUN_BIN" x --help
  fi

  case "$1" in
    -v | --version)
      npm_version
      exit 0
      ;;
  esac

  while (($# > 0)); do
    case "$1" in
      -y | --yes | --ignore-existing)
        ;;
      --package)
        bunx_args+=("--package")
        shift
        if (($# > 0)); then
          bunx_args+=("$1")
        fi
        ;;
      *)
        bunx_args+=("$1")
        ;;
    esac
    shift
  done

  exec "$BUN_BIN" x --bun "${bunx_args[@]}"
}

run_node() {
  if [[ $# -eq 0 ]]; then
    exec "$BUN_BIN" repl
  fi

  case "$1" in
    -v | --version)
      node_version
      exit 0
      ;;
    --)
      shift
      exec "$BUN_BIN" "$@"
      ;;
    *)
      exec "$BUN_BIN" "$@"
      ;;
  esac
}

run_npm_config() {
  local global_bin

  case "${1:-}" in
    get)
      case "${2:-}" in
        cache)
          exec "$BUN_BIN" pm cache
          ;;
        prefix)
          global_bin="$("$BUN_BIN" pm bin -g)"
          dirname "$global_bin"
          ;;
        registry)
          printf 'https://registry.npmjs.org/\n'
          ;;
        user-agent)
          printf 'bun/%s npm-compat/%s node/%s\n' "$(bun_version)" "$(npm_version)" "$(node_version_without_prefix)"
          ;;
        *)
          printf 'undefined\n'
          ;;
      esac
      exit 0
      ;;
    set | delete | rm)
      exit 0
      ;;
    list | ls)
      printf '; bun npm-compat shim\n'
      exit 0
      ;;
    *)
      exec "$BUN_BIN" pm pkg "$@"
      ;;
  esac
}

run_npm() {
  local command_name

  if [[ $# -eq 0 ]]; then
    exec "$BUN_BIN" --help
  fi

  command_name="$1"
  shift

  case "$command_name" in
    -v | --version)
      npm_version
      ;;
    version)
      if [[ "${1:-}" == "--json" ]]; then
        printf '{"npm":"%s","node":"%s","bun":"%s"}\n' "$(npm_version)" "$(node_version_without_prefix)" "$(bun_version)"
      else
        exec "$BUN_BIN" pm version "$@"
      fi
      ;;
    init)
      case " $* " in
        *" -y "* | *" --yes "* | "  ")
          ensure_package_json
          ;;
        *)
          exec "$BUN_BIN" init "$@"
          ;;
      esac
      ;;
    install | i)
      translate_package_args "$@"
      exec "$BUN_BIN" install "${translated_args[@]}"
      ;;
    ci)
      translate_package_args "$@"
      exec "$BUN_BIN" install --frozen-lockfile "${translated_args[@]}"
      ;;
    add)
      translate_package_args "$@"
      exec "$BUN_BIN" add "${translated_args[@]}"
      ;;
    uninstall | un | remove | rm)
      translate_package_args "$@"
      exec "$BUN_BIN" remove "${translated_args[@]}"
      ;;
    run)
      exec "$BUN_BIN" run "$@"
      ;;
    test | start | stop | restart)
      exec "$BUN_BIN" run "$command_name" "$@"
      ;;
    exec | x)
      run_bunx "$@"
      ;;
    create)
      exec "$BUN_BIN" create "$@"
      ;;
    update | upgrade)
      translate_package_args "$@"
      exec "$BUN_BIN" update "${translated_args[@]}"
      ;;
    view | info)
      exec "$BUN_BIN" info "$@"
      ;;
    publish | audit | outdated | why | link | unlink | patch)
      exec "$BUN_BIN" "$command_name" "$@"
      ;;
    config)
      run_npm_config "$@"
      ;;
    bin)
      if [[ "${1:-}" == "-g" || "${1:-}" == "--global" ]]; then
        exec "$BUN_BIN" pm bin -g
      fi
      exec "$BUN_BIN" pm bin
      ;;
    root)
      if [[ "${1:-}" == "-g" || "${1:-}" == "--global" ]]; then
        dirname "$("$BUN_BIN" pm bin -g)"
      else
        printf '%s\n' "$(pwd)/node_modules"
      fi
      ;;
    *)
      exec "$BUN_BIN" "$command_name" "$@"
      ;;
  esac
}

run_yarn() {
  local command_name

  if [[ $# -eq 0 ]]; then
    exec "$BUN_BIN" --help
  fi

  command_name="$1"
  shift

  case "$command_name" in
    -v | --version)
      yarn_version
      ;;
    install)
      translate_package_args "$@"
      exec "$BUN_BIN" install "${translated_args[@]}"
      ;;
    add)
      translate_package_args "$@"
      exec "$BUN_BIN" add "${translated_args[@]}"
      ;;
    remove | rm)
      exec "$BUN_BIN" remove "$@"
      ;;
    run)
      exec "$BUN_BIN" run "$@"
      ;;
    dlx | exec)
      run_bunx "$@"
      ;;
    upgrade | up)
      exec "$BUN_BIN" update "$@"
      ;;
    why)
      exec "$BUN_BIN" why "$@"
      ;;
    global)
      case "${1:-}" in
        add)
          shift
          exec "$BUN_BIN" install --global "$@"
          ;;
        remove | rm)
          shift
          exec "$BUN_BIN" remove --global "$@"
          ;;
        *)
          exec "$BUN_BIN" "$command_name" "$@"
          ;;
      esac
      ;;
    *)
      exec "$BUN_BIN" run "$command_name" "$@"
      ;;
  esac
}

run_pnpm() {
  local command_name

  if [[ $# -eq 0 ]]; then
    exec "$BUN_BIN" --help
  fi

  command_name="$1"
  shift

  case "$command_name" in
    -v | --version)
      pnpm_version
      ;;
    install | i)
      translate_package_args "$@"
      exec "$BUN_BIN" install "${translated_args[@]}"
      ;;
    add)
      translate_package_args "$@"
      exec "$BUN_BIN" add "${translated_args[@]}"
      ;;
    remove | rm | uninstall | un)
      exec "$BUN_BIN" remove "$@"
      ;;
    run)
      exec "$BUN_BIN" run "$@"
      ;;
    exec | dlx)
      run_bunx "$@"
      ;;
    update | up | upgrade)
      exec "$BUN_BIN" update "$@"
      ;;
    why)
      exec "$BUN_BIN" why "$@"
      ;;
    *)
      exec "$BUN_BIN" "$command_name" "$@"
      ;;
  esac
}

run_corepack() {
  case "${1:-}" in
    -v | --version)
      corepack_version
      ;;
    enable | disable | prepare | install | use | pack | hydrate)
      exit 0
      ;;
    *)
      exit 0
      ;;
  esac
}

case "$(basename "$0")" in
  node)
    run_node "$@"
    ;;
  npm)
    run_npm "$@"
    ;;
  npx | pnpx)
    run_bunx "$@"
    ;;
  yarn | yarnpkg)
    run_yarn "$@"
    ;;
  pnpm)
    run_pnpm "$@"
    ;;
  corepack)
    run_corepack "$@"
    ;;
  *)
    exec "$BUN_BIN" "$@"
    ;;
esac
SHIM
  done
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
  parse_args "$@"

  ensure_dir "$HOME/.config"
  ensure_dir "$HOME/.dotfile-backups"
  prepend_path_if_dir "$HOME/.bun/bin"
  prepend_path_if_dir "$HOME/.local/bin"
  prepend_path_if_dir "$HOME/.cargo/bin"

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

  if ((SKIP_USER_TOOL_INSTALLS)); then
    log_skip "User-local tool installation skipped by option"
  else
    install_rust
    install_bun
    install_uv
    install_python_tools
    install_yazi
    install_oh_my_zsh
    install_oh_my_zsh_plugins
  fi

  if ((SKIP_PACKAGE_INSTALLS && SKIP_USER_TOOL_INSTALLS && !FORCE_NEOVIM_UPGRADE)); then
    log_skip "Neovim fallback skipped by option"
  else
    ensure_usable_neovim
  fi

  verify_oh_my_zsh_plugins
  ensure_generated_zshrc

  ensure_link "$REPO_ROOT/tmux/.tmux.conf" "$HOME/.tmux.conf"

  if [[ -f "$REPO_ROOT/git/.gitconfig" ]]; then
    ensure_link "$REPO_ROOT/git/.gitconfig" "$HOME/.gitconfig"
  else
    log_skip "git/.gitconfig is absent, skipped gitconfig management"
  fi

  ensure_link "$REPO_ROOT/nvim" "$HOME/.config/nvim"
  ensure_link "$REPO_ROOT/yazi" "$HOME/.config/yazi"
  ensure_dir "$REPO_ROOT/.claude"
  ensure_link "$REPO_ROOT/.claude" "$HOME/.claude"
  ensure_dir "$REPO_ROOT/.codex"
  ensure_link "$REPO_ROOT/.codex" "$HOME/.codex"

  # Use Bun as the JavaScript runtime surface so tools with Node.js/npm/npx
  # expectations work without installing Node.js/npm separately.
  ensure_bun_node_shims

  check_runtime_tools
  switch_default_shell
  print_summary
}

main "$@"
