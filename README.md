
Made for [hunjam 2026](https://www.hunjam.hu/)

## Play

**https://lvntszcs.github.io/hunjam26/**: pick `main` or `testing` at the top of the page.

## Build status

| Branch | Web export (deployed commit) | Build & deploy workflow |
|---|---|---|
| `main` | [![main build](https://img.shields.io/endpoint?url=https%3A%2F%2Flvntszcs.github.io%2Fhunjam26%2Fmain%2Fbadge.json)](https://github.com/lvntszcs/hunjam26/commits/main) | [![main deploy](https://github.com/lvntszcs/hunjam26/actions/workflows/pages.yml/badge.svg?branch=main&event=push)](https://github.com/lvntszcs/hunjam26/actions/workflows/pages.yml?query=branch%3Amain) |
| `testing` | [![testing build](https://img.shields.io/endpoint?url=https%3A%2F%2Flvntszcs.github.io%2Fhunjam26%2Ftesting%2Fbadge.json)](https://github.com/lvntszcs/hunjam26/commits/testing) | [![testing deploy](https://github.com/lvntszcs/hunjam26/actions/workflows/pages.yml/badge.svg?branch=testing&event=push)](https://github.com/lvntszcs/hunjam26/actions/workflows/pages.yml?query=branch%3Atesting) |

- **Web export:** the commit currently live on the site for that branch, green if its Godot web export succeeded, red if it failed. Read from `<branch>/badge.json` on the Pages site, so it only changes when a deploy succeeds (refreshed within ~5 minutes).
- **Build & deploy workflow:** the result of the latest [`pages.yml`](.github/workflows/pages.yml) run started by a push to that branch. Every run rebuilds and deploys both branches.
