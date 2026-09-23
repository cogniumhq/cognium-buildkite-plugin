**# Cognium SAST Buildkite Plugin**

Run Cognium static application security testing scans in Buildkite.

**## Example**

```yaml

steps:

  - label: ":shield: Cognium SAST"

    command: ":"

    plugins:

      - cogniumhq/cognium#v1.0.1:

          path: .

```

The plugin provides the Buildkite \`command\` hook, so you do not need to add a separate \`command:\` step for the Cognium scan.

**## Configuration**

| Option | Type | Default | Description |

|---|---|---|---|

| \`path\` | string | \`.\` | Path to scan |

| \`package-version\` | string | \`4.9.16\` | Version of \`cognium-dev\` to install |

| \`format\` | string | \`text\` | Output format: \`text\`, \`json\`, or \`sarif\` |

| \`output\` | string | — | Output file |

| \`severity\` | string | — | Severity filter |

| \`category\` | string | — | Category filter |

| \`fail-on-findings\` | boolean | \`false\` | Whether security findings should cause the Buildkite step to fail |

**### Finding behavior**

By default, security findings are reported without failing the Buildkite step:

```yaml

steps:

  - label: ":shield: Cognium SAST"

    command: ":"

    plugins:

      - cogniumhq/cognium#v1.0.1:

          path: .

          fail-on-findings: false

```

To use Cognium as a blocking security gate, set \`fail-on-findings\` to \`true\`:

```yaml

steps:

  - label: ":shield: Cognium SAST"

    command: ":"

    plugins:

      - cogniumhq/cognium#v1.0.1:

          path: .

          fail-on-findings: true

```

Scanner errors and installation failures remain non-zero regardless of \`fail-on-findings\`.

**### SARIF / JSON artifacts**

To make a SARIF or JSON report available as a Buildkite artifact, configure the plugin's \`output\` and the step's \`artifact\_paths\`:

```yaml

steps:

  - label: ":shield: Cognium SAST"

    artifact\_paths:

      - "cognium-results.sarif"

    plugins:

      - cogniumhq/cognium#v1.0.1:

          path: .

          format: sarif

          output: cognium-results.sarif

```

**## Requirements**

\- Buildkite Agent

\- Node.js >= 20.19.0

\- npm

**## How It Works**

The plugin installs the specified version of \`cognium-dev\` into a temporary directory using npm and runs a Cognium SAST scan against the configured path.

```text

Buildkite

    |

    v

Cognium Buildkite Plugin

    |

    v

Install cognium-dev

    |

    v

cognium-dev scan

    |

    v

Security findings

```

If Cognium detects security findings, the plugin follows the \`fail-on-findings\` setting. When \`false\`, findings are reported without failing the Buildkite step. When \`true\`, findings cause the step to fail.

Scanner and installation errors remain non-zero regardless of \`fail-on-findings\`.

**## Development**

Run the Buildkite plugin linter:

```shell

docker run -it --rm -v "$PWD:/plugin\:ro" buildkite/plugin-linter --id cogniumhq/cognium --path /plugin

```

Run the plugin tests:

```shell

docker run -it --rm -v "$PWD:/plugin\:ro" buildkite/plugin-tester

```

**## LICENSE**

MIT