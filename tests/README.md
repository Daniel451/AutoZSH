# Tests and Benchmarks

Run syntax validation from the repository root:

```zsh
zsh -n zshrc
bash -n install.sh
```

`benchmark.zsh` measures a copied version of the repository configuration in
a temporary home directory. It symlinks the current user's Oh My Zsh install,
but uses a separate zoxide database and never changes the user's configuration
or Git settings.

The default is 300 measured samples and 10 warm-up samples. Results are TSV so
slow samples can be inspected directly. By default, they are written to the
ignored `tests/output/` directory. Interactive runs show progress for warm-up
and measured samples; redirected and CI runs suppress the progress bars while
retaining status and summary output. The terminal summary reports minimum,
maximum, median, and mean timing for each metric, alongside status messages for
setup and each benchmark phase. Each phase also displays whether it is a
no-config shell control or configured-Zsh test.

```zsh
zsh tests/benchmark.zsh
```

The command above runs baseline, startup, and navigation benchmarks. Pass
`baseline`, `startup`, or `navigation` to run only that benchmark. The baseline
uses empty non-Git directories inside its temporary sandbox to compare cold Bash
and bare-Zsh startup plus process-and-`cd` timing. Navigation benchmarks use
`fixtures/default.txt` by default. Its paths are
resolved from the repository root. To benchmark other directories, copy
`fixtures/directories.example.txt`, replace the entries with existing absolute
paths, then pass that file explicitly:

```zsh
zsh tests/benchmark.zsh navigation \
  --directories /path/to/directories.txt \
  --seed 451
```

Each navigation sample starts from `/`, measures `cd` and `z` independently,
then measures the configured `prompt_git` component at the destination. The
printed seed reproduces the directory-selection sequence. Navigation initializes
one isolated Zsh session for the full sequence, so its timings do not include
startup and retain the state of an existing shell session.

Use `--plugins` to override the Oh My Zsh plugin array for a comparison:

```zsh
zsh tests/benchmark.zsh startup --plugins 'git,zoxide'
```

Focused benchmark runs can use `--output FILE` to write results somewhere other
than the default `tests/output/baseline.tsv`, `tests/output/startup.tsv`, or
`tests/output/navigation.tsv`. The complete suite always writes those three
separate default files.

Every run ends with a checkup grouped into startup and navigation controls. It
flags samples taking more than one second. When both baseline and configured
startup tests run, it also reports material median advantages: at least 20% and
20ms faster.

The terminal labels use three categories: `bash no-config` is Bash without
profiles or rc files, `zsh no-config` is Zsh without configuration files, and
`zsh config` loads the supplied rc file, which defaults to this repository's
`zshrc`.

The benchmark does not configure `core.fsmonitor` or `core.untrackedCache`.
Those are global Git settings, so any comparison involving them should use an
explicit temporary `GIT_CONFIG_GLOBAL` outside the installer.