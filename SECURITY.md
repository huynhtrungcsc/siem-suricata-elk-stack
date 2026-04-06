# Security Policy

## Scope

This repository contains **documentation only** — no executable application code, dependencies, or deployable services are distributed here. As such, the attack surface is limited to documentation accuracy and the security implications of the configurations described within.

---

## Reporting a Vulnerability

If you identify any of the following issues, please report them responsibly:

| Category | Examples |
|---|---|
| **Configuration errors** | Documented commands or settings that introduce security risks if followed |
| **Outdated guidance** | Steps referencing deprecated versions with known CVEs |
| **Credential handling** | Any inadvertent inclusion of sensitive data in examples |

### How to Report

**Do not open a public GitHub issue for security-sensitive findings.**

Instead, please contact the maintainer directly via one of the following channels:

- **GitHub Private Advisory:** Navigate to the repository's **Security** tab → **Report a vulnerability**
- **Email:** Create a GitHub issue requesting private contact details if the above is unavailable

Please include:

1. A description of the issue
2. The affected file(s) and line(s)
3. The potential impact if a user follows the documented steps
4. Suggested correction (if available)

---

## Response Timeline

| Stage | Target Timeframe |
|---|---|
| Acknowledgement | Within 48 hours |
| Assessment | Within 7 days |
| Resolution / disclosure | Within 30 days |

---

## Out of Scope

The following are outside the scope of this security policy:

- Vulnerabilities in upstream software (Suricata, Elasticsearch, Kibana, Filebeat) — please report those to the respective projects.
- General questions about configuring or hardening these tools beyond what is documented here.

---

## Acknowledgements

Responsibly disclosed security issues will be acknowledged in the relevant commit message and release notes.
