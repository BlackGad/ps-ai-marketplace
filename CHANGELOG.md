# Changelog

## [0.16.0](https://github.com/BlackGad/ps-legion-marketplace/compare/v0.15.0...v0.16.0) (2026-11-24)


### Features

* **python:** accounts and launchers in Python ([#69](https://github.com/BlackGad/ps-legion-marketplace/issues/69)) ([b0746d1](https://github.com/BlackGad/ps-legion-marketplace/commit/b0746d19a38a82d304e9ab00a000b136f8d4b581))
* **python:** channels in Python ([#65](https://github.com/BlackGad/ps-legion-marketplace/issues/65)) ([ea156e0](https://github.com/BlackGad/ps-legion-marketplace/commit/ea156e0cdfa77e94626bbcd9dbeac5e4df31e918))
* **python:** footprints and settings core ([#67](https://github.com/BlackGad/ps-legion-marketplace/issues/67)) ([c19597e](https://github.com/BlackGad/ps-legion-marketplace/commit/c19597eb9e8a8257f6d83905f0d01c284d1ef1fb))
* **python:** Foundry accounts and runner in Python ([#70](https://github.com/BlackGad/ps-legion-marketplace/issues/70)) ([982c3e4](https://github.com/BlackGad/ps-legion-marketplace/commit/982c3e40b07ff5ad21b42385f5d76f2f8780547f))
* **python:** refresh and app lifecycle in Python ([#71](https://github.com/BlackGad/ps-legion-marketplace/issues/71)) ([23d1190](https://github.com/BlackGad/ps-legion-marketplace/commit/23d11907e9a9ca77b399af8661369bbc1b0c9aef))
* **python:** repository setup in Python ([#64](https://github.com/BlackGad/ps-legion-marketplace/issues/64)) ([1cc335e](https://github.com/BlackGad/ps-legion-marketplace/commit/1cc335e84a340eb372903fdf24b27eaf7add089e))


### Fixes

* milestone 3 end-review fixes ([#74](https://github.com/BlackGad/ps-legion-marketplace/issues/74)) ([9fc61dc](https://github.com/BlackGad/ps-legion-marketplace/commit/9fc61dc9fa61eaa73de2f82ad6227a783df32a19))


### Refactoring

* overseer and setup use Python validate and lease ([#72](https://github.com/BlackGad/ps-legion-marketplace/issues/72)) ([7fc506c](https://github.com/BlackGad/ps-legion-marketplace/commit/7fc506c2d24f41f8ece0e6739c81e2ccdce7cde6))


### Tests

* fence Git config for every Python test ([#68](https://github.com/BlackGad/ps-legion-marketplace/issues/68)) ([bc55d86](https://github.com/BlackGad/ps-legion-marketplace/commit/bc55d865c54f90054252395b3755e7c9820de69f))
* **integration:** milestone 3 verbs without pwsh ([#73](https://github.com/BlackGad/ps-legion-marketplace/issues/73)) ([b252925](https://github.com/BlackGad/ps-legion-marketplace/commit/b252925202d95be012b1b4f5abc095ed4c262439))

## [0.15.0](https://github.com/BlackGad/ps-legion-marketplace/compare/v0.14.0...v0.15.0) (2026-11-24)


### Features

* **hooks:** start sessions without PowerShell ([#53](https://github.com/BlackGad/ps-legion-marketplace/issues/53)) ([082253b](https://github.com/BlackGad/ps-legion-marketplace/commit/082253b8ac9799fe0efbdf60299c68fcaec8f2c3))
* **python:** check for legion updates in Python ([#52](https://github.com/BlackGad/ps-legion-marketplace/issues/52)) ([45041dc](https://github.com/BlackGad/ps-legion-marketplace/commit/45041dccc56525bf25244b2e758f7fb5eabf9a48))
* **python:** read account limits in Python ([#56](https://github.com/BlackGad/ps-legion-marketplace/issues/56)) ([6b6be55](https://github.com/BlackGad/ps-legion-marketplace/commit/6b6be5558cb3471981e7626b844aa7d227412189))
* **python:** show legion status in Python ([#55](https://github.com/BlackGad/ps-legion-marketplace/issues/55)) ([f00157b](https://github.com/BlackGad/ps-legion-marketplace/commit/f00157b2c4e740dba57fc5a502bd8dfd3c1edd96))
* **python:** take and release the overseer lease in Python ([#51](https://github.com/BlackGad/ps-legion-marketplace/issues/51)) ([bc2cc84](https://github.com/BlackGad/ps-legion-marketplace/commit/bc2cc84b698bb1511b4e0202e3812643ca904381))


### Fixes

* close milestone 2 review findings on test fences and wording ([#57](https://github.com/BlackGad/ps-legion-marketplace/issues/57)) ([8858f83](https://github.com/BlackGad/ps-legion-marketplace/commit/8858f83a25329686cd02c059c3fbc6ed9cdc4fbd))
* close milestone 2 third review findings ([#62](https://github.com/BlackGad/ps-legion-marketplace/issues/62)) ([e5e68dd](https://github.com/BlackGad/ps-legion-marketplace/commit/e5e68ddf5a84a8170bfe56a944c589fcce1bed3e))
* **overseer:** say when a channel's bot folder or token is missing ([#54](https://github.com/BlackGad/ps-legion-marketplace/issues/54)) ([9505b2a](https://github.com/BlackGad/ps-legion-marketplace/commit/9505b2a9a48f3c3fa17510847f1fbb96bc0b4dbc))
* **python:** close milestone 2 review findings on process, lease and cache robustness ([#58](https://github.com/BlackGad/ps-legion-marketplace/issues/58)) ([2945179](https://github.com/BlackGad/ps-legion-marketplace/commit/2945179cef347ed7f6026816f7edd5fb6565875b))
* **python:** close milestone 2 second review findings on lease, nudge and update ([#60](https://github.com/BlackGad/ps-legion-marketplace/issues/60)) ([bdf312c](https://github.com/BlackGad/ps-legion-marketplace/commit/bdf312c5969c900a3c871da4a850a17d6067f52b))
* **tests:** keep tests out of the real user PATH ([#49](https://github.com/BlackGad/ps-legion-marketplace/issues/49)) ([ba7af00](https://github.com/BlackGad/ps-legion-marketplace/commit/ba7af007ca8cd66c41f69b4d705a8abad2571be3))

## [0.14.0](https://github.com/BlackGad/ps-legion-marketplace/compare/v0.13.1...v0.14.0) (2026-11-23)


### ⚠ BREAKING CHANGES

* **python:** rename the CLI to legion and parse arguments with Click ([#45](https://github.com/BlackGad/ps-legion-marketplace/issues/45))

### Features

* **python:** rename the CLI to legion and parse arguments with Click ([#45](https://github.com/BlackGad/ps-legion-marketplace/issues/45)) ([65f8951](https://github.com/BlackGad/ps-legion-marketplace/commit/65f8951383063408bb5ca4575b12631acb8b47e3))
* **python:** validate settings in Python with typed pydantic models ([#48](https://github.com/BlackGad/ps-legion-marketplace/issues/48)) ([51583c5](https://github.com/BlackGad/ps-legion-marketplace/commit/51583c5fad83705dc7a1a31e7887b4fbc0f2f64f))
* run the legion command from the Python app in the legion folder ([#47](https://github.com/BlackGad/ps-legion-marketplace/issues/47)) ([ad39f52](https://github.com/BlackGad/ps-legion-marketplace/commit/ad39f520b5978bbd37789ca03481c30c0ed7a219))

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
