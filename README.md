# AutoZSH

AutoZSH is an open source easy install & default configuration wrapper
for the Z Shell and [oh-my-zsh](https://ohmyz.sh).
The project aims to
provide a quick start with a feature-rich `zsh` environment. It installs
`oh-my-zsh` together with several plugins and supplies a default `zshrc`
file featuring default key bindings and some custom functions.

This project is distributed under the **Creative Commons
Attribution‑ShareAlike 4.0** International License.

You are free to share
and adapt the code as long as:
   1. **you give appropriate credit** and
   2. you **distribute your contributions under the same terms***

## Forks, Redistribution (+Giving Credit)

If you fork, redistribute or embed AutoZSH:

1. Include a link "AutoZSH" to this repository in your README or documentation.
2. Attribute the original author:
   ```
   AutoZSH was created by Daniel Speck (github.com/daniel451)
   Licensed under CC-BY-SA 4.0
   Redistribution permitted given you copy and include this notice and
   distribute your works under the same license.
   ```
3. Keep this license notice and include any changes you made.
4. If you publish derivative work, license it under the same CC BY-SA 4.0 terms.

## Prerequisites

The installer expects the following tools to be available:

- `zsh`
- `git`
- `curl`
- `fzy`
- `fzf`

Note: `zoxide` is installed automatically by the script.

## Installation

You can install AutoZSH with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/Daniel451/AutoZSH/main/install.sh | bash
```

The script will:
- Check for required dependencies.
- Install oh-my-zsh and plugins.
- Configure your `.zshrc`.
- Backup existing configuration if present.

To customize the installation or run manually:
1. Clone this repository.
2. Run `./install.sh`.

## Customizing your configuration

After installation the provided `zshrc` becomes your `$HOME/.zshrc`.
Feel free to modify this file to tailor themes, plugins or any other
settings to your preference.
