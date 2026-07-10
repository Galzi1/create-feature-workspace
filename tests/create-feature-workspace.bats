setup() {
    SCRIPT="create-feature-workspace.sh"
    BATS_TMP_DIR="$(mktemp -d)"
    TEMP_WS_ROOT="$BATS_TMP_DIR/workspaces"
    CONFIG_FILE="$BATS_TMP_DIR/test-config.ini"
    SHIM_DIR="$BATS_TMP_DIR/bin"
    mkdir -p "$SHIM_DIR"
    cat << 'SHIM' > "$SHIM_DIR/git"
#!/bin/bash
echo "MOCK GIT CALLED: $*" >&2
if [[ "$*" == *"worktree add"* ]]; then
    args=("$@")
    count=$#
    dest="${args[$((count - 2))]}"
    mkdir -p "$dest"
fi
exit 0
SHIM
    chmod +x "$SHIM_DIR/git"
    OLD_PATH="$PATH"
    export PATH="$SHIM_DIR:$PATH"
}

teardown() {
    export PATH="$OLD_PATH"
    rm -rf "$BATS_TMP_DIR"
}

@test "Successfully calls git worktree add for a valid config" {
    cat << 'EOF' > "$CONFIG_FILE"
[repo1]
name = repo-alpha
path = /fake/repo
branch = main
EOF
    run bash "$BATS_TEST_DIRNAME/../$SCRIPT" --feature-name "new-feat" --config-file "$CONFIG_FILE" --workspaces-root "$TEMP_WS_ROOT"
    echo "$output" >&2
    [ "$status" -eq 0 ]
    [ -d "$TEMP_WS_ROOT/new-feat/repo-alpha" ]
}

@test "Expands tilde (~) in paths" {
    cat << 'EOF' > "$CONFIG_FILE"
[repo1]
name = repo-alpha
path = ~/fake-repo
branch = main
EOF
    run bash "$BATS_TEST_DIRNAME/../$SCRIPT" --feature-name "test-tilde" --config-file "$CONFIG_FILE" --workspaces-root "$TEMP_WS_ROOT"
    echo "$output" >&2
    [ "$status" -eq 0 ]
}

@test "Fails on malformed config (missing key)" {
    cat << 'EOF' > "$CONFIG_FILE"
[repo1]
name = repo-alpha
branch = main
EOF
    run bash "$BATS_TEST_DIRNAME/../$SCRIPT" --feature-name "fail-feat" --config-file "$CONFIG_FILE" --workspaces-root "$TEMP_WS_ROOT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Missing name/path/branch"* ]]
}
