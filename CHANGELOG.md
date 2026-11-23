# Changelog

## [0.13.1](https://github.com/BlackGad/ps-legion-marketplace/compare/v0.13.0...v0.13.1) (2026-11-23)


### Fixes

* **overseer:** keep a Codex overseer on Telegram reachable ([#43](https://github.com/BlackGad/ps-legion-marketplace/issues/43)) ([bff29a4](https://github.com/BlackGad/ps-legion-marketplace/commit/bff29a44b9f9f7f56b677c1f0517187646a8e40d))

## [0.13.0](https://github.com/BlackGad/ps-legion-marketplace/compare/v0.12.0...v0.13.0) (2026-11-23)


### Features

* **inbox:** add repository overseer messages ([#40](https://github.com/BlackGad/ps-legion-marketplace/issues/40)) ([65f2e4d](https://github.com/BlackGad/ps-legion-marketplace/commit/65f2e4d9bc8b07cc93058275b6241426bec2984c))
* **python:** add uv project and CLI bridge ([#37](https://github.com/BlackGad/ps-legion-marketplace/issues/37)) ([c32bb95](https://github.com/BlackGad/ps-legion-marketplace/commit/c32bb95374a12ab34360471f403b572ecc215845))
* **telegram:** give each overseer its own bot ([#38](https://github.com/BlackGad/ps-legion-marketplace/issues/38)) ([3b52015](https://github.com/BlackGad/ps-legion-marketplace/commit/3b5201524e1a52bd624fedb423917719925471a2))
* **telegram:** run Telegram on Codex through a bridge and send script ([#41](https://github.com/BlackGad/ps-legion-marketplace/issues/41)) ([cf439d2](https://github.com/BlackGad/ps-legion-marketplace/commit/cf439d24fda9e2be69ad75276fb27a854282c506))


### Fixes

* **ci:** pass the token to the report timing step ([#42](https://github.com/BlackGad/ps-legion-marketplace/issues/42)) ([664ffbf](https://github.com/BlackGad/ps-legion-marketplace/commit/664ffbf89ec5cad67d74b14d42d4d35f210708e3))

## [0.12.0](https://github.com/BlackGad/ps-legion-marketplace/compare/v0.11.0...v0.12.0) (2026-11-22)


### Features

* **bin:** one limits command for every tool ([e054896](https://github.com/BlackGad/ps-legion-marketplace/commit/e054896c7e11170a370add95122459a745df32d2))
* **install:** one-line install for macOS and Linux that sets up PowerShell 7 ([e054896](https://github.com/BlackGad/ps-legion-marketplace/commit/e054896c7e11170a370add95122459a745df32d2))
* **install:** uninstall and purge from a footprint index ([e054896](https://github.com/BlackGad/ps-legion-marketplace/commit/e054896c7e11170a370add95122459a745df32d2))
* **setup:** add legion to the shell profile PATH on macOS and Linux ([e054896](https://github.com/BlackGad/ps-legion-marketplace/commit/e054896c7e11170a370add95122459a745df32d2))


### Fixes

* **install:** PowerShell 7.4 is the minimum ([e054896](https://github.com/BlackGad/ps-legion-marketplace/commit/e054896c7e11170a370add95122459a745df32d2))
* **install:** record only what legion adds and ask before recording it ([e054896](https://github.com/BlackGad/ps-legion-marketplace/commit/e054896c7e11170a370add95122459a745df32d2))
* **install:** refuse a linked ~/.legion/bin and stop purge when records changed after its preview ([e054896](https://github.com/BlackGad/ps-legion-marketplace/commit/e054896c7e11170a370add95122459a745df32d2))
* **install:** remove the owner command when its last target is uninstalled ([e054896](https://github.com/BlackGad/ps-legion-marketplace/commit/e054896c7e11170a370add95122459a745df32d2))
* **limits:** limit checks no longer load the current repository's settings and hooks ([e054896](https://github.com/BlackGad/ps-legion-marketplace/commit/e054896c7e11170a370add95122459a745df32d2))


### Documentation

* **overseer:** three rules at the top of the checklist ([e054896](https://github.com/BlackGad/ps-legion-marketplace/commit/e054896c7e11170a370add95122459a745df32d2))

## [0.11.0](https://github.com/BlackGad/ps-legion-marketplace/compare/v0.10.0...v0.11.0) (2026-11-21)


### Features

* **hooks:** warn when a bound channel is not connected ([#33](https://github.com/BlackGad/ps-legion-marketplace/issues/33)) ([df0fc29](https://github.com/BlackGad/ps-legion-marketplace/commit/df0fc2903acd67896707a68b969499c580367ffe))
* **setup:** allow the overseer to start legion members in Claude ([#31](https://github.com/BlackGad/ps-legion-marketplace/issues/31)) ([f323f76](https://github.com/BlackGad/ps-legion-marketplace/commit/f323f766b88a71774df100cd6a937fbb4bfeab1e))


### Fixes

* **ci:** pass the source fallback only on a direct main push ([#34](https://github.com/BlackGad/ps-legion-marketplace/issues/34)) ([b81f52c](https://github.com/BlackGad/ps-legion-marketplace/commit/b81f52c867e2ea861c425f8ecded83cba0e3598c))
* point links and defaults to ps-legion-marketplace ([#30](https://github.com/BlackGad/ps-legion-marketplace/issues/30)) ([258fb6f](https://github.com/BlackGad/ps-legion-marketplace/commit/258fb6fe23c5373a1a222df99044d4cee57f3600))

## [0.10.0](https://github.com/BlackGad/ps-ai-marketplace/compare/v0.9.0...v0.10.0) (2026-11-21)


### ⚠ BREAKING CHANGES

* uninstall the previous plugin before installing legion@ps-legion-marketplace. No plugin migration is provided.

### Features

* rename ps-ai to legion ([#28](https://github.com/BlackGad/ps-ai-marketplace/issues/28)) ([92aedc5](https://github.com/BlackGad/ps-ai-marketplace/commit/92aedc50a9553ebc67e834e27ece664aadd87b54))

## [0.9.0](https://github.com/BlackGad/ps-ai-marketplace/compare/v0.8.0...v0.9.0) (2026-11-21)


### Features

* **install:** add uninstall purge that removes every ps-ai trace ([#27](https://github.com/BlackGad/ps-ai-marketplace/issues/27)) ([cd40a91](https://github.com/BlackGad/ps-ai-marketplace/commit/cd40a91dd47d5f9ade37e45a93919045ae8f9de7))


### Fixes

* **install:** keep account launchers across reinstall ([#25](https://github.com/BlackGad/ps-ai-marketplace/issues/25)) ([dd1f1e2](https://github.com/BlackGad/ps-ai-marketplace/commit/dd1f1e24ff3b8bec7902c00fb609f3ddbf22a5e6))

## [0.8.0](https://github.com/BlackGad/ps-ai-marketplace/compare/v0.7.0...v0.8.0) (2026-11-21)


### Features

* easy install, update, uninstall and overseer restore ([#24](https://github.com/BlackGad/ps-ai-marketplace/issues/24)) ([1fb9fcd](https://github.com/BlackGad/ps-ai-marketplace/commit/1fb9fcd7129b53b10026fe5c1691b2d5c0364176))


### Documentation

* add release summary to the GitHub Release, not the release pull request ([#22](https://github.com/BlackGad/ps-ai-marketplace/issues/22)) ([ede19d2](https://github.com/BlackGad/ps-ai-marketplace/commit/ede19d2ab4640d26d27d9ca5c694003463986a92))

## [0.7.0](https://github.com/BlackGad/ps-ai-marketplace/compare/v0.6.0...v0.7.0) (2026-11-20)


### Features

* releases, CI and integration runs ([#17](https://github.com/BlackGad/ps-ai-marketplace/issues/17)) ([8bdb409](https://github.com/BlackGad/ps-ai-marketplace/commit/8bdb4096a868b75dc9350f691a603083fc4f4134))
* **skills:** confirm channel requests with a reaction ([#16](https://github.com/BlackGad/ps-ai-marketplace/issues/16)) ([b5ef24b](https://github.com/BlackGad/ps-ai-marketplace/commit/b5ef24b40c37a33ed6d82d11bdb2cf9bfccb985a))


### Fixes

* **claude:** legion runs never start channel plugins ([#18](https://github.com/BlackGad/ps-ai-marketplace/issues/18)) ([dbbd838](https://github.com/BlackGad/ps-ai-marketplace/commit/dbbd838093edde9ff72af2fc1c98aef44fc31870))
