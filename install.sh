#!/bin/bash

# automatically terminate on error
set -e

REPO_URL="https://raw.githubusercontent.com/Daniel451/AutoZSH/main"

echo -e "Welcome to AutoZSH installer.\n"

echo "This installer will install oh-my-zsh alongside with plugins \
for autocompletion and deploy a feature-rich .zshrc config file to start \
with. The installation requires all dependencies to be installed (this will \
be checked by the installer. Root privileges are NOT needed as the installer \
will just locally deploy everything for the currently active user and in this \
user's home directory."

if [ -z "$HOME" ]; then
    echo "HOME is not set. Attempting to detect..."
    if command -v getent &> /dev/null; then
        export HOME=$(getent passwd $(whoami) | cut -d: -f6)
    else
        export HOME=$(eval echo ~$(whoami))
    fi
    echo "Detected HOME: $HOME"
fi

if [ "$HOME" = "/root" ] && [ "$(whoami)" != "root" ]; then
    echo "HOME is set to /root but user is $(whoami). correcting HOME..."
    if command -v getent &> /dev/null; then
        export HOME=$(getent passwd $(whoami) | cut -d: -f6)
    else
        export HOME=$(eval echo ~$(whoami))
    fi
    echo "Corrected HOME: $HOME"
fi

echo -e "\nInstalling to directory:\n$HOME/.oh-my-zsh\n"
export ZSH="$HOME/.oh-my-zsh"

if [ -t 1 ]; then
    is_interactive=true
else
    is_interactive=false
fi

# allow environment to override interactivity
if [ -n "$NONINTERACTIVE" ]; then
    is_interactive=false
fi

# INSTALL_LOCAL_DEPS=1 accepts the user-local installation of fzf / zoxide
# in non-interactive mode; it changes nothing in interactive mode, which
# always asks
install_local_deps=false
if [ -n "$INSTALL_LOCAL_DEPS" ] && [ "$INSTALL_LOCAL_DEPS" != "0" ]; then
    install_local_deps=true
fi

# ask for installation only if interactive
if [ "$is_interactive" = true ]; then
    echo -n "Do you want to continue (Y/n)? "
    read response < /dev/tty
    if [[ "$(echo "$response" | tr '[:upper:]' '[:lower:]')" == "y" || "$response" == "" ]]; then
        echo -e "proceeding with installation..."
    else
        echo "installation aborted."
        exit 1
    fi
else
    echo "Non-interactive mode detected. Proceeding with installation..."
fi

# check for previous oh-my-zsh installation
if [[ -d "$ZSH" ]]; then
    echo -e "\nAn existing oh-my-zsh installation was found at $ZSH."
    if [ "$is_interactive" = true ]; then
        echo -n "Do you want to re-install (y/N)? "
        read reinstall < /dev/tty
        if [[ "$(echo "$reinstall" | tr '[:upper:]' '[:lower:]')" == "y" ]]; then
            echo "Removing previous installation..."
            rm -rf "$ZSH"
        else
            echo -e "\nInstallation aborted. To reinstall, remove $ZSH first.\n"
            exit 1
        fi
    else
        echo "Non-interactive mode: Overwriting existing installation..."
        rm -rf "$ZSH"
    fi
fi

# inline checks from autozsh-checkup.sh
# hard requirements: system-wide zsh, git, curl
check_command() {
  if ! command -v "$1" &> /dev/null; then
    echo "Error: $1 is not installed on the system."
    exit 1
  fi
}

# minimum fzf version for the Ctrl-p / Ctrl-t navigation widgets,
# which rely on fzf's built-in directory walker (introduced in 0.47,
# stable since 0.48)
FZF_MIN_VERSION="0.48"
FZF_PINNED_VERSION="0.74.5"

# prints the installed fzf version or nothing when fzf is absent/unparseable.
# tolerates both "fzf 0.35.0 (sha)" (legacy) and "0.74.3 (sha)" output formats
# and only emits purely numeric dotted versions, so version_at_least never
# receives non-numeric fields
installed_fzf_version() {
  command -v fzf &> /dev/null || return 1
  local ver
  ver="$(fzf --version 2> /dev/null | head -n 1)"
  ver="${ver#fzf }"
  ver="${ver%% *}"
  [[ "$ver" =~ ^[0-9]+([.][0-9]+)*$ ]] || return 1
  echo "$ver"
}

# version comparison without sort -V (not available on macOS/BSD):
# splits into numeric fields and compares pairwise
version_at_least() {
  local candidate="$1" minimum="$2"
  local c_major c_minor remainder m_major m_minor
  c_major="${candidate%%.*}"
  remainder="${candidate#*.}"
  c_minor="${remainder%%.*}"
  m_major="${minimum%%.*}"
  remainder="${minimum#*.}"
  m_minor="${remainder%%.*}"
  # tolerate non-numeric or missing fields by normalizing to 0
  [ "${c_major:-0}" -ge "${m_major:-0}" ] || return 1
  [ "${c_major:-0}" -gt "${m_major:-0}" ] && return 0
  [ "${c_minor:-0}" -ge "${m_minor:-0}" ] || return 1
  return 0
}

# user-local binary target shared by the fzf and zoxide routines
LOCAL_BIN="$HOME/.local/bin"

# installs a pinned fzf release into $LOCAL_BIN (no root required).
# resolves platform + architecture from uname, like the zoxide installer does.
install_fzf_locally() {
  local os arch asset tmp_dir
  os="$(uname -s)"
  case "$os" in
    Linux)  os="linux" ;;
    Darwin) os="darwin" ;;
    *)
      echo "Error: unsupported platform '$os' for local fzf installation."
      echo "Install fzf (version ${FZF_MIN_VERSION} or newer) manually and rerun."
      return 1
      ;;
  esac
  arch="$(uname -m)"
  case "$arch" in
    x86_64)          arch="amd64" ;;
    aarch64|arm64)   arch="arm64" ;;
    armv7l|armv7)    arch="armv7" ;;
    armv6l|armv6)    arch="armv6" ;;
    *)
      echo "Error: unsupported architecture '$arch' for local fzf installation."
      echo "Install fzf (version ${FZF_MIN_VERSION} or newer) manually and rerun."
      return 1
      ;;
  esac

  asset="fzf-${FZF_PINNED_VERSION}-${os}_${arch}.tar.gz"
  echo "Downloading ${asset}..."
  mkdir -p "$LOCAL_BIN"
  tmp_dir="$(mktemp -d)"
  if ! curl -fsSL "https://github.com/junegunn/fzf/releases/download/v${FZF_PINNED_VERSION}/${asset}" \
       | tar -xz -C "$tmp_dir" \
    || ! install -m 0755 "$tmp_dir/fzf" "$LOCAL_BIN/fzf"; then
    rm -rf "$tmp_dir"
    echo "Error: local fzf installation failed. Install fzf (version ${FZF_MIN_VERSION} or newer) manually and rerun."
    return 1
  fi
  rm -rf "$tmp_dir"
  echo "Installed fzf ${FZF_PINNED_VERSION} to ${LOCAL_BIN}/fzf"
}

# installs zoxide via the official installer into $HOME/.local/bin
install_zoxide_locally() {
  echo "Installing zoxide locally (installer default: \$HOME/.local/bin)..."
  # the upstream script uses $SHELL/sh; pin bash for predictable behavior
  if ! curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash; then
    echo "Error: local zoxide installation failed. Install it manually (https://github.com/ajeetdsouza/zoxide#installation) and rerun."
    return 1
  fi
  echo "zoxide installed."
}

# fzf is required: when absent or older than the walker minimum it is
# installed locally into $HOME/.local/bin; declining or failing aborts
ensure_fzf() {
  local version
  if version="$(installed_fzf_version)" && [ -n "$version" ]; then
    if version_at_least "$version" "$FZF_MIN_VERSION"; then
      echo "Found fzf ${version}."
      return 0
    fi
    echo "fzf ${version} found, but ${FZF_MIN_VERSION} or newer is required for"
    echo "the navigation widgets."
  else
    echo "fzf is not installed on the system."
  fi

  if [ "$install_local_deps" != true ] && [ "$is_interactive" != true ]; then
    echo "Error: fzf >= ${FZF_MIN_VERSION} is required. Set INSTALL_LOCAL_DEPS=1 to install it into \$HOME/.local/bin, or install it system-wide."
    return 1
  fi
  if [ "$is_interactive" = true ]; then
    echo -n "Install fzf ${FZF_PINNED_VERSION} locally to \$HOME/.local/bin? (Y/n) "
    read response < /dev/tty
    response="$(echo "$response" | tr '[:upper:]' '[:lower:]')"
    if [ "$response" = "n" ] || [ "$response" = "no" ]; then
      echo "Error: fzf >= ${FZF_MIN_VERSION} is required. Install it system-wide or rerun and accept the local installation."
      return 1
    fi
  fi
  install_fzf_locally || return 1
  export PATH="${LOCAL_BIN}:${PATH}"
  command -v fzf &> /dev/null
}

# zoxide is required: ships prebuilt binaries and installs to
# $HOME/.local/bin by default; declining or failing aborts
ensure_zoxide() {
  if command -v zoxide &> /dev/null; then
    echo "Found zoxide."
    return 0
  fi
  echo "zoxide is not installed on the system."
  if [ "$install_local_deps" != true ] && [ "$is_interactive" != true ]; then
    echo "Error: zoxide is required. Set INSTALL_LOCAL_DEPS=1 to install it into \$HOME/.local/bin, or install it system-wide."
    return 1
  fi
  if [ "$is_interactive" = true ]; then
    echo -n "Install zoxide locally to \$HOME/.local/bin? (Y/n) "
    read response < /dev/tty
    response="$(echo "$response" | tr '[:upper:]' '[:lower:]')"
    if [ "$response" = "n" ] || [ "$response" = "no" ]; then
      echo "Error: zoxide is required. Install it system-wide or rerun and accept the local installation."
      return 1
    fi
  fi
  install_zoxide_locally || return 1
  export PATH="${LOCAL_BIN}:${PATH}"
  command -v zoxide &> /dev/null
}

check_command "zsh"
check_command "git"
check_command "curl"
# fzf and zoxide are required: the ensure_* functions return non-zero on
# decline, missing tool, or failed local installation
ensure_fzf || exit 1
ensure_zoxide || exit 1

# install oh-my-zsh
echo -e "installing oh-my-zsh...\n"
# Explicitly set ZSH directory to current user's home to avoid permission issues
# when running via sudo or su without full login shell
export ZSH="$HOME/.oh-my-zsh"
RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# install plugins
echo -e "installing plugins...\n"
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"

# zsh-autosuggestions
echo -e "[1] zsh-autosuggestions...\n"
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM}/plugins/zsh-autosuggestions || true
echo ""

# zsh-syntax-highlighting
echo -e "[2] zsh-syntax-highlighting...\n"
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting || true
echo ""

# zsh-completions
echo -e "[3] zsh-completions...\n"
git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM}/plugins/zsh-completions || true
echo ""

# conda-zsh-completions
echo -e "[4] conda-zsh-completion...\n"
git clone https://github.com/conda-incubator/conda-zsh-completion.git ${ZSH_CUSTOM}/plugins/conda-zsh-completion || true
echo ""

echo -e "done.\n"

# deploy config
if [[ -f "${HOME}/.zshrc" ]]; then
    echo -e "backup existing .zshrc file...\n"
    cp "${HOME}/.zshrc" "${HOME}/.zshrc.backup"
    echo -e "Existing .zshrc file backed up to ${HOME}/.zshrc.backup\n"
fi

echo -e "deploying zshrc file (config)...\n"
# use local zshrc if available, otherwise download
if [ -f "zshrc" ]; then
    echo "Using local zshrc configuration..."
    cp zshrc "${HOME}/.zshrc"
else
    echo "Downloading zshrc from GitHub..."
    curl -fsSL "$REPO_URL/zshrc" > "${HOME}/.zshrc"
fi

echo -e "\nInstallation complete! Please restart your terminal or run 'zsh'.\n"
