# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it responsibly.

**Please do NOT open a public GitHub Issue for security vulnerabilities.**

Instead, please report security issues by emailing **plantry.sup@gmail.com** with:

- A description of the vulnerability
- Steps to reproduce the issue
- Any potential impact

We will acknowledge receipt within 48 hours and provide an estimated timeline for a fix.

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| Latest  | :white_check_mark: |

## Security Practices

- API keys and secrets are managed via `Configs/Secrets.xcconfig` (excluded from version control)
- CloudKit sync is automatically disabled in CI/test environments
- The app uses Core Data with CloudKit for data storage with automatic conflict resolution
