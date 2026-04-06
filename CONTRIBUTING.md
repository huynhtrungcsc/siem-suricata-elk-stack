# Contributing

Thank you for your interest in contributing to this project. Contributions that improve accuracy, clarity, coverage, or accessibility of the documentation are welcome.

---

## Table of Contents

- [Types of Contributions](#types-of-contributions)
- [Getting Started](#getting-started)
- [Documentation Standards](#documentation-standards)
- [Commit Message Convention](#commit-message-convention)
- [Pull Request Process](#pull-request-process)
- [Code of Conduct](#code-of-conduct)

---

## Types of Contributions

The following contributions are encouraged:

| Type | Description |
|---|---|
| **Bug reports** | Incorrect commands, broken links, outdated package versions |
| **Technical corrections** | Factual errors in configuration steps or command outputs |
| **Clarifications** | Rewording unclear or ambiguous instructions |
| **Translation improvements** | Corrections to the Vietnamese (`vi/`) documentation |
| **New content** | Additional guides, troubleshooting sections, or platform variants |

---

## Getting Started

1. Fork the repository.
2. Create a descriptive branch:

   ```bash
   git checkout -b docs/fix-filebeat-output-config
   ```

3. Make your changes following the standards below.
4. Open a pull request against the `main` branch.

---

## Documentation Standards

### File Naming

| Language | Convention | Example |
|---|---|---|
| English | `NN-kebab-case.md` | `03-configure-ips.md` |
| Vietnamese | `NN-chu-thuong.md` | `03-cau-hinh-ips.md` |

### YAML Frontmatter

Every document must include the following frontmatter block:

```yaml
---
title: "..."
description: "..."
author: "..."
date: YYYY-MM-DD
category: Security
series: "SIEM with Suricata and Elastic Stack"
part: N
tags:
  - tag1
  - tag2
---
```

### Document Structure

Each guide must follow this structure:

1. YAML frontmatter
2. H1 title
3. Metadata table (Series, Part, Difficulty, Time, OS)
4. Table of Contents
5. Introduction
6. Prerequisites
7. Numbered steps (H2)
8. Summary
9. References
10. Navigation table

### Heading Hierarchy

- Use **H1** for the document title only.
- Use **H2** for major sections (Introduction, Step N, Summary, etc.).
- Use **H3** for subsections within a step.
- Do not skip levels.

### Code Blocks

Always specify the language identifier:

````markdown
```bash
sudo systemctl restart suricata.service
```
````

---

## Commit Message Convention

This project follows the [Conventional Commits](https://www.conventionalcommits.org/) specification.

### Format

```
<type>(<scope>): <summary>

[optional body]
```

### Types

| Type | Usage |
|---|---|
| `docs` | Documentation content changes |
| `fix` | Corrections to commands, configurations, or factual errors |
| `feat` | New guides or sections |
| `refactor` | Restructuring without content changes |
| `chore` | Maintenance (file renames, metadata updates) |
| `ci` | Changes to repository automation or workflows |

### Examples

```
docs(en): add troubleshooting section to Part 4 Filebeat configuration
fix(vi): correct suricata-update command in Part 1
feat(en): add Part 6 covering Suricata rule performance tuning
chore: update YAML frontmatter dates across all documents
```

---

## Pull Request Process

1. Ensure your changes pass a manual review against the documentation standards above.
2. Provide a clear description of what was changed and why.
3. Link any related issues.
4. A maintainer will review and merge or request revisions within a reasonable timeframe.

---

## Code of Conduct

This project adopts the [Contributor Covenant Code of Conduct](https://www.contributor-covenant.org/version/2/1/code_of_conduct/). By participating, you agree to uphold this standard in all project spaces.
