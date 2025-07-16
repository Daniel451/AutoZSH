# ZephyrZSH

ZephyrZSH is an open source configuration for the Z Shell that aims to
provide a quick start with a feature-rich `zsh` environment. It installs
oh-my-zsh together with several plugins and supplies a default `zshrc`
file.

This project is distributed under the Creative Commons
Attribution‑ShareAlike 4.0 International License. You are free to share
and adapt the code provided you give appropriate credit and distribute
your contributions under the same terms.

## Prerequisites

The installer expects the following tools to be available:

- `zsh`
- `git`
- `curl`
- `fzy`
- `fzf`

## Running the installer

1. Clone this repository and open the directory.
2. Execute `./zephyr-install.sh`.
   - The script prompts for confirmation.
   - It invokes `zephyr-checkup.sh` to verify dependencies.
   - oh-my-zsh and all plugins are downloaded and installed locally.
   - Finally, the `zshrc` file is copied to `$HOME/.zshrc`.

## Checking dependencies

`zephyr-checkup.sh` can be run manually and is also used by the
installer to ensure all required commands are installed.

## Customizing your configuration

After installation the provided `zshrc` becomes your `$HOME/.zshrc`.
Feel free to modify this file to tailor themes, plugins or any other
settings to your preference.
