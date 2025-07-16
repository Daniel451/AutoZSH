#!/bin/bash

# automatically terminate on error
set -e

echo -e "Welcome to AutoZSH installer.\n"

echo "This installer will install oh-my-zsh alongside with plugins \
for autocompletion and deploy a feature-rich .zshrc config file to start \
with. The installation requires all dependencies to be installed (this will \
be checked by the installer. Root privileges are NOT needed as the installer \
will just locally deploy everything for the currently active user and in this \
user's home directory."

# ask for installation
read -rp "Do you want to continue (Y/n)? " response

# convert response to lowercase
response=${response,,}

# check user response
if [[ "$response" == y || "$response" == "" ]]; then
    echo -e "proceeding with installation..."
else
    echo "installation aborted."
    exit 1
fi

# run checkup
./autozsh-checkup.sh

# install oh-my-zsh
echo -e "installing oh-my-zsh...\n"
ZSH="$HOME/.oh-my-zsh" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# install plugins
echo -e "installing plugins...\n"
ZSH="$HOME/.oh-my-zsh"
ZSH_CUSTOM="$ZSH/custom"

# zsh-autosuggestions
echo -e "[1] zsh-autosuggestions...\n"
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM}/plugins/zsh-autosuggestions
echo ""

# zsh-syntax-highlighting
echo -e "[2] zsh-syntax-highlighting...\n"
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting
echo ""

# zsh-fzy
echo -e "[3] zsh-fzy...\n"
git clone https://github.com/aperezdc/zsh-fzy.git ${ZSH_CUSTOM}/plugins/zsh-fzy
echo ""

# zsh-completions
echo -e "[4] zsh-completions...\n"
git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM}/plugins/zsh-completions
echo ""

# conda-zsh-completions
echo -e "[5] conda-zsh-completion...\n"
git clone https://github.com/conda-incubator/conda-zsh-completion.git ${ZSH_CUSTOM}/plugins/conda-zsh-completion
echo ""

# zoxide
echo -e "[6] zoxide...\n"
curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
echo ""

echo -e "done.\n"

# deploy config
echo -e "deploying zshrc file (config)...\n"
cp zshrc ${HOME}/.zshrc









