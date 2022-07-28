## Why

Healthy projects under active development rapidly accumulate many small scripts to
scratch various itches. The grind idiom [^1] is to organize these scripts into a tree of
commands separated from rest of the codebase, that are all executed via single shell
script ([`grind`](grind)).

This approach has a number of advantages:

- Commands are easily discoverable, because they are all in one place.
- Commands can run even when the main system is broken in various ways e.g. in the
  course of bootstrapping and upgrades.
- Commands are unlikely to be accidentally shipped to production.
- Commands run quickly, because they are self-contained. If `grind` were e.g. a
  monolithic Python application, it would need to import the dependencies of all of its
  sub-commands.

## Getting Started

Clone the repo somewhere sane:

```bash
mkdir -p ~/git
cd ~/git
git clone https://github.com/moshelooks/grind.git
```

Sourcing the main script creates an [alias] so you can `grind` anywhere, and enables
[tab completion]. This is not strictly necessary, but is recommended for ergonomics:

```bash
echo 'source ~/git/grind/grind' >> ~/.bashrc
source ~/.bashrc
```

To see it in action:

```bash
cd ~/git/grind
grind
```

## Under the Hood

Consider `grind examples hello_world`:

- `examples` is the *group* corresponding to the directory [`commands/examples/`].
- `hello_world` is the *command* corresponding the script
  [`commands/examples/hello_world`].

There is only one group in this example, but groups may be nested arbitrarily inside of
other groups; `grind arg1 arg2 arg3 ... argN` walks down the tree at [`commands/`] until
it reaches an executable script `commands/arg1/.../argM` which gets run with
`argM+1 argM+2 ... argN` as its arguments.

## Using Grind in Your Project

Create a `commands` directory in the root of you repo. Add some commands. Group related
commands in sub-directories and add `README.md` files as breadcrumbs.

### Adding a New Command

Grind commands are arbitrary executable files anywhere under `commmands/`. Commands can
expect the following environment variables to be set:

- `REPO_ROOT_DIR` - absolute path to the root of their repository.
- `GRIND` - absolute path to the `grind` script itself.
- `MARKDOWN_READER` - a program that reads markdown from standard in and renders it to
  standard out. This defaults to `glow -w 93` if [glow] is installed, falling back to
  `cat` if `glow` is not found.

The following bash functions are also available for commands to utilize:

- `docstring` - documents commands with inline markdown.
- `bad_args` - prints an informative message to standard error and exits with status 1.

For example, the `grind hello_world` command is:

```bash
#!/bin/bash
set -eu -o pipefail
docstring <<\EOF
Prints `Hello, World!` to standard output.

Does not accept any arguments.
EOF
(($#)) && bad_args "$@"

echo "Hello, World!"
```

The call to the `docstring` function uses a [here document] with an escaped limit string
so that the docstring can contain arbitrary control characters.

> :information_source: If your command is anything other than a bash script then you
> must add a `cmd.md` file documenting the command in the same directory as your
> executable, where `cmd` is the name of the executable. You can also do this when your
> executable _is_ a bash script, in lieu of utilizing the `docstring` function.

### Customization

This is the fun part! If a `.grind.bash` file is found in the root of your repository,
`grind` will `source` it prior to command execution. The most obvious things to put in
here are useful environment variables and bash functions that you would like to export
to your commands. To get an idea of what's possible, consider the `grind presubmit`
command:

```bash
#!/bin/bash
set -eu -o pipefail
docstring <<\EOF
Checks for unstaged changes or untracked files, and runs shellcheck.

The check for unstaged changes and untracked files may be skipped with
`ALLOW_UNSTAGED=1` or by passing in `--allow-unstaged`.
EOF
if ! (($#)); then
    if [ ! -v ALLOW_UNSTAGED ]; then
	check_unstaged
    fi
elif ! [[ $# -eq 1 && $1 =~ ^\-{0,2}allow-unstaged$ ]]; then
    bad_args "$@"
fi

echo -n "Checking bash scripts with shellcheck ... "
cd "${REPO_ROOT_DIR}"
TARGETS=( $(grovel_commands) $(grovel_files "*.bash") grind )
shellcheck -e SC2207 "${TARGETS[@]}"
echo "OK"
```

This makes use of a number of functions defined in `.grind.bash`:

- `check_unstaged` - prints information about unstaged changes and untracked files, and
  exits with status 1 if any are found.
- `grovel_commands` - uses `find` to list executables under `commands/`.
- `grovel_files` - uses `git ls-files` to list files in the repo, respecting git's
  ignore rules.

Yes, `grind` is itself a project that uses `grind` to manage it's own meager repertoire
of scripts; so meta!

> :information_source: The `MARKDOWN_READER` environment variable is only set if it is
> undefined after sourcing `.grind.bash`. This means that you may set it to the command
> of your liking on a per-project basis, or as a personal customization by setting it as
> an environment variable in your `.bashrc` or similar. If you want to stick with [glow]
> for reading markdown but customize its output, use `GLOW_ARGS`; e.g. say
> `GLOW_ARGS="-w 80"` for narrower output.

[^1]: Adapted from https://github.com/crutcher/smot/.

[alias]: https://tldp.org/LDP/Bash-Beginners-Guide/html/sect_03_05.html
[glow]: https://github.com/charmbracelet/glow
[here document]: https://tldp.org/LDP/abs/html/here-docs.html
[tab completion]: https://en.wikipedia.org/wiki/Command-line_completion
[`commands/examples/hello_world`]: commands/examples/hello_world
[`commands/examples/`]: commands/examples/
[`commands/`]: commands/
