# The custom command execution environment for grind itself.

function grovel_commands() {
    find "${REPO_ROOT_DIR}/commands" -type f -executable "$@"
}
export -f grovel_commands

function grovel_files() {
    git ls-files -oc --exclude-standard "$@"
}
export -f grovel_files

function check_unstaged() {
    echo -n "Checking for unstaged changes ... "
    local unstaged
    unstaged=$(git diff --name-only)
    if [ -n "${unstaged}" ]; then
	echo -e "\nERROR: Repository has unstaged changes.\n" 1>&2
	git status
	exit 1
    fi
    echo -e -n "OK\nChecking for untracked files ... "
    local untracked
    untracked=$(git ls-files --others --exclude-standard)
    if [ -n "${untracked}" ]; then
	echo -e "\nERROR: Repository has untracked files.\n" 1>&2
	git status
	exit 1
    fi
    echo "OK"
}
export -f check_unstaged
