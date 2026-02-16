# Contributing to VDD Framework

VDD Framework へのコントリビューションを歓迎します！

Thank you for your interest in contributing to VDD Framework!

## How to Contribute / コントリビューション方法

### Reporting Issues / 問題の報告

- Use GitHub Issues to report bugs or suggest features
- バグ報告や機能提案には GitHub Issues を使ってください
- Include your adoption level (L1-L5) and project type when reporting issues
- 問題報告時には採用レベル（L1-L5）とプロジェクトタイプを含めてください

### Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Make your changes
4. Run validation: `bash scripts/validate.sh`
5. Run tests: `bash tests/test-hooks.sh`
6. Commit your changes
7. Push to your fork and submit a PR

### Documentation / ドキュメント

Documentation is maintained in both English and Japanese:
ドキュメントは英語と日本語の両方で管理されています：

- `docs/en/` — English documentation
- `docs/ja/` — 日本語ドキュメント

When making documentation changes, please update both languages.
ドキュメントの変更時は、両方の言語を更新してください。

### Adding Examples / 参照実装の追加

We welcome real-world examples! If your project uses VDD Framework, consider contributing it as an example:
実プロジェクトでの参照実装を歓迎します！

1. Create a directory under `examples/your-project/`
2. Include a `README.md` explaining your setup
3. Remove all secrets, tokens, and sensitive information
4. Note which adoption level you're using

### Hook Development / フック開発

When creating or modifying hooks:
フックの作成・修正時：

- Use bash only (no zsh or other shell dependencies)
- Ensure compatibility with both macOS and Linux
- Source `vdd.config` for project-specific values
- Include tests in `tests/test-hooks.sh`
- Follow the existing enforcement level conventions (L5/L4/L3/L2)

### Skill Development / スキル開発

When creating or modifying skills:
スキルの作成・修正時：

- Use `{{PLACEHOLDER}}` for project-specific values
- Reference `vdd.config` variables where appropriate
- Include usage examples in the skill file
- Keep skills tool-agnostic where possible

## Code Style / コードスタイル

### Shell Scripts
- Use `#!/bin/bash` (not `#!/bin/sh`)
- Include `set -euo pipefail` for safety
- Use functions for reusable logic
- Comment in English (code) + Japanese (user-facing messages where appropriate)

### Markdown
- Use ATX-style headings (`#`)
- One sentence per line where practical
- Include cross-links between related documents

## Release Process / リリースプロセス

VDD Framework itself follows semantic versioning:
VDD Framework 自体もセマンティックバージョニングに従います：

- **patch**: Bug fixes, typos, minor documentation updates
- **minor**: New skills, new hooks, new examples, documentation improvements
- **major**: Breaking changes to template structure, hook API changes

## License / ライセンス

By contributing, you agree that your contributions will be licensed under the MIT License.
コントリビューションすることで、MIT ライセンスの下でライセンスされることに同意するものとします。

## Questions? / 質問

Open an issue or start a discussion on GitHub.
GitHub で Issue を開くか、Discussion を開始してください。
