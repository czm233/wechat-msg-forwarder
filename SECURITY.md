# Security Policy

## Reporting a vulnerability

Please avoid filing a public issue for a vulnerability that could expose local
chat exports. Contact the repository maintainer privately through the security
reporting channel configured on GitHub.

Do not attach real WeChat exports. A minimal synthetic ZIP is sufficient for
reproduction.

## Security model

- The Share Extension accepts a file supplied by the macOS sharing system.
- The original ZIP is copied into an App Group before the temporary input dies.
- Preview parsing reads text through the system `tar` tool without extracting
  archive entries to disk. It limits output size and candidate count, and filters
  unsafe paths in fallback text-entry selection. It does not implement a full
  ZIP-format validator.
- Generated HTML disables scripts and network connections through CSP and the
  embedded WebView also disables JavaScript.
- The project contains no HTTP client, updater, telemetry or cloud integration.
