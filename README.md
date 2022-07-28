## Why

Healthy projects under active development rapidly accumulate many small scripts to
scratch various itches. The grind idiom [^1] is to organize these scripts into a tree of
commands separated from rest of the codebase, that are all executed via single bash
script ([`grind`](grind)).

This approach has a number of advantages:

- Commands are easily discoverable, because they are all in one place.
- Commands can run even when the main system is broken in various ways e.g. in the
  course of bootstrapping and upgrades.
- Commands can easily dispatch to other commands in a predictable environment.
- Commands are unlikely to be accidentally shipped to production.
- Commands run quickly, because they are self-contained. If `grind` were e.g. a
  monolithic Python application, it would need to import the dependencies of all of its
  sub-commands.

## Prerequisites

It is recommended to install [glow] for rendering markdown. On Debian/Ubuntu:

```bash
echo 'deb [trusted=yes] https://repo.charm.sh/apt/ /' | sudo tee /etc/apt/sources.list.d/charm.list
sudo apt update && sudo apt install glow
```

See [here](https://github.com/charmbracelet/glow#installation) for other installation
options.

## Getting Started

Clone the repo somewhere sane e.g.:

```bash
git clone https://github.com/moshelooks/grind.git ~/git/grind/
```

Sourcing the main script creates an [alias] so you can `grind` anywhere, and enables
[tab completion]. This is not strictly necessary but is recommended for ergonomics:

```bash
echo 'source ~/git/grind/grind' >> ~/.bashrc
source ~/.bashrc
```

To see it in action:

```bash
cd ~/git/grind
# list top-level commands and groups
grind
# list commands and sub-groups in the 'examples' group
grind examples
# show help for the 'hello_world' command in the 'examples' group
grind help examples hello_world
# run it
grind examples hello_world
```

## Under the Hood

When `grind examples hello_world` is executed, `grind` goes up the directory tree
starting from the current working directory to find the root of a git repository
(`REPO_ROOT_DIR`), then runs `${REPO_ROOT_DIR}/commands/examples/hello_world`.

- `examples` is the *group* corresponding to the directory [`commands/examples/`].
- `hello_world` is the *command* corresponding the script
  [`commands/examples/hello_world`].

There is only one group in this example, but groups may be nested arbitrarily inside of
other groups; `grind arg1 arg2 arg3 ... argN` walks down the directory tree from
`${REPO_ROOT_DIR}/commands/` until it reaches an executable file `arg1/.../argM`
(${M}\\leq{N}$) which gets run with `argM+1 argM+2 ... argN` as its arguments.

## Using Grind in Your Project

Create a `commands` directory in the root of you repo. Add some commands. Group related
commands in sub-directories and add `README.md` files as breadcrumbs.

### Adding a New Command

Grind commands are arbitrary executable files anywhere under `commmands/`. Commands can
expect the following environment variables to be set:

- `REPO_ROOT_DIR` - absolute path to the root of their repository.
- `GRIND` - absolute path to the `grind` script itself.
- `MARKDOWN_READER` - a shell command that reads markdown from standard in and renders
  it to standard out. The default is `glow -w 93` if [glow] is installed, falling back
  to `cat` if `glow` is not found.

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

The `docstring` function call uses a [here document] with an escaped limit string so
that the docstring can contain arbitrary control characters.

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

This makes use of a number of functions defined in `grind`'s own
[`.grind.bash`](.grind.bash) file:

- `check_unstaged` - prints information about unstaged changes and untracked files, and
  exits with status 1 if any are found.
- `grovel_commands` - uses `find` to list executables under `commands/`.
- `grovel_files` - uses `git ls-files` to list files in the repo, respecting git's
  ignore rules.

Yes, `grind` is itself a project that uses `grind` to manage it's own meager repertoire
of scripts; so meta!

The use-case for `.grind.bash` is project-level customization. You can also add
user-level customizations to `${REPO_ROOT_DIR}/.grind.local.bash` [^2]. If user-level
customizations are found, they will be _additionally_ applied after the project-level
customizations. For example you can say \`MARKDOWN_READER="glow -w 80" if you prefer
narrower output, or swap out glow for some other markdown renderer.

> :information_source: Add `/.grind.local.bash` to you `.gitignore` so this guy doesn't
> get checked in to your repo by accident.

______________________________________________________________________

[^1]: Adapted from [crutcher/smot](https://github.com/crutcher/smot/).

[^2]: If this file doesn't exist then `grind` will look for a "global" user customization
    file to source instead, located in `${XDG_CONFIG_HOME}/grind.bash`, or in
    `${HOME}/.config/grind.bash` if `XDG_CONFIG_HOME` is unset.

[alias]: https://tldp.org/LDP/Bash-Beginners-Guide/html/sect_03_05.html
[glow]: https://github.com/charmbracelet/glow
[here document]: https://tldp.org/LDP/abs/html/here-docs.html
[tab completion]: https://en.wikipedia.org/wiki/Command-line_completion
[`commands/examples/hello_world`]: commands/examples/hello_world
[`commands/examples/`]: commands/examples/
