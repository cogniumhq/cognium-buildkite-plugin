# Cognium SAST Buildkite Plugin

Run Cognium static application security testing scans in Buildkite.

## Example

```yaml
steps:
  - command: echo "Run Cognium"
    plugins:
      - cogniumhq/cognium#v1.0.0:
          path: .
```

## Configuration

| Option | Type | Default | Description |
|---|---|---|---|
| `path` | string | `.` | Path to scan |
| `package-version` | string | `4.9.16` | Version of `cognium-dev` to install |
| `format` | string | `text` | Output format: `text`, `json`, or `sarif` |
| `output` | string | — | Output file |
| `severity` | string | — | Severity filter |
| `category` | string | — | Category filter |

## Requirements

- Buildkite Agent
- Node.js >= 20.19.0
- npm

## How It Works

The plugin installs `cognium-dev` using npm and runs a Cognium SAST scan against the configured path.

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

## Development

Run the plugin linter:

```shell
docker run -it --rm -v "$PWD:/plugin:ro" buildkite/plugin-linter --id cogniumhq/cognium --path /plugin
```

Run the plugin tests:

```shell
docker run -it --rm -v "$PWD:/plugin:ro" buildkite/plugin-tester
```

## License

Apache-2.0