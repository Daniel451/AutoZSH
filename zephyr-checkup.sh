#!/bin/bash

echo "Checking dependencies..."

# checks if a command is available
check_command() {
  if ! command -v "$1" &> /dev/null; then
    echo "Error: $1 is not installed on the system."
    exit 1
  fi
}

# check if requirements are installed
check_command "zsh"
check_command "git"
check_command "curl"
check_command "fzy"
check_command "fzf"

echo -e "done!\n"
