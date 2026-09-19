#!/usr/bin/env bats

setup() {
  export TEST_BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$TEST_BIN"

  # Fake npm.
  # The plugin calls:
  #
  # npm install --prefix "$INSTALL_DIR" --no-save "cognium-dev@..."
  #
  # Therefore $3 is the temporary installation directory.
  cat > "$TEST_BIN/npm" <<'EOF'
#!/bin/bash

set -euo pipefail

PREFIX="$3"

mkdir -p "$PREFIX/node_modules/.bin"

cat > "$PREFIX/node_modules/.bin/cognium-dev" <<'COGNIUM'
#!/bin/bash

printf '%s\n' "$@" > "$BATS_TEST_TMPDIR/cognium-args"
exit 0
COGNIUM

chmod +x "$PREFIX/node_modules/.bin/cognium-dev"
EOF

  chmod +x "$TEST_BIN/npm"

  export PATH="$TEST_BIN:$PATH"
}

@test "plugin has a command hook" {
  [ -f "$PWD/hooks/command" ]
}

@test "plugin command hook uses cognium-dev" {
  run grep "cognium-dev" "$PWD/hooks/command"
  [ "$status" -eq 0 ]
}

@test "plugin runs cognium scan with default configuration" {
  run bash "$PWD/hooks/command"

  [ "$status" -eq 0 ]

  run cat "$BATS_TEST_TMPDIR/cognium-args"

  [ "$status" -eq 0 ]
  [ "$output" = $'scan\n.\n--format\ntext' ]
}

@test "plugin passes path configuration" {
  export BUILDKITE_PLUGIN_COGNIUM_PATH="./src"

  run bash "$PWD/hooks/command"

  [ "$status" -eq 0 ]

  run cat "$BATS_TEST_TMPDIR/cognium-args"

  [ "$status" -eq 0 ]
  [ "$output" = $'scan\n./src\n--format\ntext' ]
}

@test "plugin passes format configuration" {
  export BUILDKITE_PLUGIN_COGNIUM_FORMAT="sarif"

  run bash "$PWD/hooks/command"

  [ "$status" -eq 0 ]

  run cat "$BATS_TEST_TMPDIR/cognium-args"

  [ "$status" -eq 0 ]
  [ "$output" = $'scan\n.\n--format\nsarif' ]
}

@test "plugin passes output configuration" {
  export BUILDKITE_PLUGIN_COGNIUM_OUTPUT="results.sarif"

  run bash "$PWD/hooks/command"

  [ "$status" -eq 0 ]

  run cat "$BATS_TEST_TMPDIR/cognium-args"

  [ "$status" -eq 0 ]
  [ "$output" = $'scan\n.\n--format\ntext\n--output\nresults.sarif' ]
}

@test "plugin passes severity configuration" {
  export BUILDKITE_PLUGIN_COGNIUM_SEVERITY="critical,high"

  run bash "$PWD/hooks/command"

  [ "$status" -eq 0 ]

  run cat "$BATS_TEST_TMPDIR/cognium-args"

  [ "$status" -eq 0 ]
  [ "$output" = $'scan\n.\n--format\ntext\n--severity\ncritical,high' ]
}

@test "plugin passes category configuration" {
  export BUILDKITE_PLUGIN_COGNIUM_CATEGORY="security"

  run bash "$PWD/hooks/command"

  [ "$status" -eq 0 ]

  run cat "$BATS_TEST_TMPDIR/cognium-args"

  [ "$status" -eq 0 ]
  [ "$output" = $'scan\n.\n--format\ntext\n--category\nsecurity' ]
}

@test "plugin passes all configuration together" {
  export BUILDKITE_PLUGIN_COGNIUM_PATH="./src"
  export BUILDKITE_PLUGIN_COGNIUM_FORMAT="sarif"
  export BUILDKITE_PLUGIN_COGNIUM_OUTPUT="cognium-results.sarif"
  export BUILDKITE_PLUGIN_COGNIUM_SEVERITY="critical,high"
  export BUILDKITE_PLUGIN_COGNIUM_CATEGORY="security"

  run bash "$PWD/hooks/command"

  [ "$status" -eq 0 ]

  run cat "$BATS_TEST_TMPDIR/cognium-args"

  [ "$status" -eq 0 ]

  [ "$output" = $'scan\n./src\n--format\nsarif\n--output\ncognium-results.sarif\n--severity\ncritical,high\n--category\nsecurity' ]
}