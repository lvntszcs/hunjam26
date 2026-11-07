# AGENTS.md

Instructions for AI coding agents working in this repository.

## Git workflow

- **Never push to `main`.** It is a protected branch.
- **Never push to `testing` directly.** It is a protected branch too.
- Push every **logical unit of development** (a feature, a fix, a refactor)
  to its **own new branch**, e.g. `feature/knock-event`, `fix/camera-resize`.
  One branch can hold several commits; you don't need a branch per commit.
- Changes reach `testing` and `main` only through pull requests.

Pushes that land on `main` or `testing` trigger the GitHub Pages workflow
(`.github/workflows/pages.yml`), which publishes the web build of each branch.
