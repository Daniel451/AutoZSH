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

# ask for installation only if interactive
if [ -t 0 ]; then
    read -rp "Do you want to continue (Y/n)? " response
    response=${response,,}
    if [[ "$response" == y || "$response" == "" ]]; then
        echo -e "proceeding with installation..."
    else
        echo "installation aborted."
        exit 1
    fi
else
    echo "Non-interactive mode detected. Proceeding with installation..."
fi

# check for previous oh-my-zsh installation
if [[ -d "$HOME/.oh-my-zsh" ]]; then
    echo -e "\nAn existing oh-my-zsh installation was found at $HOME/.oh-my-zsh."
    if [ -t 0 ]; then
        read -rp "Do you want to re-install (y/N)? " reinstall
        reinstall=${reinstall,,}
        if [[ "$reinstall" == "y" ]]; then
            echo "Removing previous installation..."
            rm -rf "$HOME/.oh-my-zsh"
        else
            echo -e "\nInstallation aborted. To reinstall, remove $HOME/.oh-my-zsh first.\n"
            exit 1
        fi
    else
        echo "Non-interactive mode: Overwriting existing installation..."
        rm -rf "$HOME/.oh-my-zsh"
    fi
fi

# inline checks from autozsh-checkup.sh
echo "Checking dependencies..."
check_command() {
  if ! command -v "$1" &> /dev/null; then
    echo "Error: $1 is not installed on the system."
    exit 1
  fi
}
check_command "zsh"
check_command "git"
check_command "curl"
check_command "fzy"
check_command "fzf"

# install oh-my-zsh
echo -e "installing oh-my-zsh...\n"
# Keep ZSH variable scope local to avoid affecting current shell? 
# Usually oh-my-zsh installer is safe.
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

# zsh-fzy
echo -e "[3] zsh-fzy...\n"
git clone https://github.com/aperezdc/zsh-fzy.git ${ZSH_CUSTOM}/plugins/zsh-fzy || true
echo ""

# zsh-completions
echo -e "[4] zsh-completions...\n"
git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM}/plugins/zsh-completions || true
echo ""

# conda-zsh-completions
echo -e "[5] conda-zsh-completion...\n"
git clone https://github.com/conda-incubator/conda-zsh-completion.git ${ZSH_CUSTOM}/plugins/conda-zsh-completion || true
echo ""

# zoxide
echo -e "[6] zoxide...\n"
curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
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
