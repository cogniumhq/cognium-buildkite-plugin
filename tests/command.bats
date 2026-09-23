#!/usr/bin/env bats

setup() {
  export TEST_BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$TEST_BIN"

  # Fake node.
  #
  # The plugin checks:
  #
  # node --version
  # node -e '...version check...'
  #
  # By default, simulate a supported Node.js version.
  cat > "$TEST_BIN/node" <<'EOF'
#!/bin/bash

set -euo pipefail

NODE_VERSION="${FAKE_NODE_VERSION:-v20.19.0}"

if [[ "$1" == "--version" ]]; then
  echo "$NODE_VERSION"
  exit 0
fi

if [[ "$1" == "-e" ]]; then
  if [[ "$NODE_VERSION" == v18.* ]]; then
    exit 1
  fi

  if [[ "$NODE_VERSION" == v20.18.* ]]; then
    exit 1
  fi

  exit 0
fi

exit 0
EOF

  chmod +x "$TEST_BIN/node"

  # Fake npm.
  #
  # The plugin calls:
  #
  # npm install \
  #   --prefix "$INSTALL_DIR" \
  #   --no-save \
  #   "cognium-dev@${PACKAGE_VERSION}"
  #
  # The fake npm records its arguments and creates a fake cognium-dev binary.
  cat > "$TEST_BIN/npm" <<'EOF'
#!/bin/bash

set -euo pipefail

printf '%s\n' "$@" > "$BATS_TEST_TMPDIR/npm-args"

PREFIX=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix)
      PREFIX="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [[ "${FAKE_NPM_FAIL:-0}" == "1" ]]; then
  exit 42
fi

if [[ -z "$PREFIX" ]]; then
  echo "Missing --prefix" >&2
  exit 43
fi

printf '%s' "$PREFIX" > "$BATS_TEST_TMPDIR/install-dir"

mkdir -p "$PREFIX/node_modules/.bin"

cat > "$PREFIX/node_modules/.bin/cognium-dev" <<'COGNIUM'
#!/bin/bash

set -euo pipefail

printf '%s\n' "$@" > "$BATS_TEST_TMPDIR/cognium-args"

case "${FAKE_COGNIUM_RESULT:-success}" in
  success)
    exit 0
    ;;

  findings)
    exit 1
    ;;

  error)
    exit "${FAKE_COGNIUM_EXIT:-7}"
    ;;

  *)
    echo "Unknown FAKE_COGNIUM_RESULT" >&2
    exit 99
    ;;
esac
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

@test "plugin passes package-version to npm" {
  export BUILDKITE_PLUGIN_COGNIUM_PACKAGE_VERSION="4.9.15"

  run bash "$PWD/hooks/command"

  [ "$status" -eq 0 ]

  run cat "$BATS_TEST_TMPDIR/npm-args"

  [ "$status" -eq 0 ]
  [ "$output" = $'install\n--prefix\n'$(cat "$BATS_TEST_TMPDIR/install-dir")$'\n--no-save\ncognium-dev@4.9.15' ]
}

@test "plugin propagates npm installation failure" {
  export FAKE_NPM_FAIL=1

  run bash "$PWD/hooks/command"

  [ "$status" -eq 42 ]
}

@test "plugin treats findings as non-fatal by default" {
  export FAKE_COGNIUM_RESULT=findings

  run bash "$PWD/hooks/command"

  [ "$status" -eq 0 ]
  [[ "$output" == *"fail-on-findings is false"* ]]
}

@test "plugin fails on findings when fail-on-findings is true" {
  export FAKE_COGNIUM_RESULT=findings
  export BUILDKITE_PLUGIN_COGNIUM_FAIL_ON_FINDINGS=true

  run bash "$PWD/hooks/command"

  [ "$status" -eq 1 ]
}

@test "plugin propagates scanner failure regardless of fail-on-findings" {
  export FAKE_COGNIUM_RESULT=error
  export FAKE_COGNIUM_EXIT=7

  run bash "$PWD/hooks/command"

  [ "$status" -eq 7 ]
}

@test "plugin propagates scanner failure when fail-on-findings is true" {
  export FAKE_COGNIUM_RESULT=error
  export FAKE_COGNIUM_EXIT=7
  export BUILDKITE_PLUGIN_COGNIUM_FAIL_ON_FINDINGS=true

  run bash "$PWD/hooks/command"

  [ "$status" -eq 7 ]
}

@test "plugin removes temporary installation directory" {
  run bash "$PWD/hooks/command"

  [ "$status" -eq 0 ]

  INSTALL_DIR="$(cat "$BATS_TEST_TMPDIR/install-dir")"

  [ ! -d "$INSTALL_DIR" ]
}

@test "plugin rejects unsupported Node.js version" {
  export FAKE_NODE_VERSION="v18.20.8"

  run bash "$PWD/hooks/command"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Node.js >= 20.19.0 is required"* ]]
  [[ "$output" == *"v18.20.8"* ]]
}