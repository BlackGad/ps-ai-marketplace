# Changelog

## [0.23.1](https://github.com/BlackGad/ps-legion-marketplace/compare/v0.23.0...v0.23.1) (2026-11-28)


### Fixes

* **install:** show bootstrap prompts, progress and result ([#139](https://github.com/BlackGad/ps-legion-marketplace/issues/139)) ([bb815b9](https://github.com/BlackGad/ps-legion-marketplace/commit/bb815b9097df1508104ea94ab73f9b29a772109a))

## [0.23.0](https://github.com/BlackGad/ps-legion-marketplace/compare/v0.22.0...v0.23.0) (2026-11-28)


### Features

* **install:** install legion as a uv tool ([#136](https://github.com/BlackGad/ps-legion-marketplace/issues/136)) ([46526eb](https://github.com/BlackGad/ps-legion-marketplace/commit/46526eb4fb569880a5fb2f41a0d23397e9795b02))


### Tests

* **mcp:** stabilize limits tests on Windows ([c0e38e4](https://github.com/BlackGad/ps-legion-marketplace/commit/c0e38e43e40f64d47d44f2af08f77b8119764fcb))
* stabilise two flaky Windows tests ([#137](https://github.com/BlackGad/ps-legion-marketplace/issues/137)) ([c0e38e4](https://github.com/BlackGad/ps-legion-marketplace/commit/c0e38e43e40f64d47d44f2af08f77b8119764fcb))

## [0.22.0](https://github.com/BlackGad/ps-legion-marketplace/compare/v0.21.0...v0.22.0) (2026-11-27)


### Features

* **hook:** list the knowledge hub at session start ([#131](https://github.com/BlackGad/ps-legion-marketplace/issues/131)) ([ae66380](https://github.com/BlackGad/ps-legion-marketplace/commit/ae663802d0f3a0fe5b0d8351df5d315acfb401ab))
* **setup:** put the knowledge hub under git ([#134](https://github.com/BlackGad/ps-legion-marketplace/issues/134)) ([4257878](https://github.com/BlackGad/ps-legion-marketplace/commit/4257878a456765a42c7474729458213f9faceff2))


### Tests

* port repository checks to pytest; one root pyproject.toml ([#133](https://github.com/BlackGad/ps-legion-marketplace/issues/133)) ([109c13e](https://github.com/BlackGad/ps-legion-marketplace/commit/109c13e36809ffc6ebdf074fc1ed52ca88194477))

## [0.21.0](https://github.com/BlackGad/ps-legion-marketplace/compare/v0.20.0...v0.21.0) (2026-11-27)


### Features

* **setup:** install the llm-wiki knowledge base in every account ([#127](https://github.com/BlackGad/ps-legion-marketplace/issues/127)) ([0e8cf25](https://github.com/BlackGad/ps-legion-marketplace/commit/0e8cf25e0d4b73a150232e72a8f66619a2035996))
* **setup:** prove the knowledge wiki on three systems; turning it off removes it ([#129](https://github.com/BlackGad/ps-legion-marketplace/issues/129)) ([0bd29af](https://github.com/BlackGad/ps-legion-marketplace/commit/0bd29af68e22250e56c3fd22dec718e5e0fcf368))

## [0.20.0](https://github.com/BlackGad/ps-legion-marketplace/compare/v0.19.0...v0.20.0) (2026-11-27)


### Features

* **limits:** check several accounts in one call, in parallel ([#125](https://github.com/BlackGad/ps-legion-marketplace/issues/125)) ([6f206a0](https://github.com/BlackGad/ps-legion-marketplace/commit/6f206a05152db46428de067c405d89539514ea3f))

## [0.19.0](https://github.com/BlackGad/ps-legion-marketplace/compare/v0.18.0...v0.19.0) (2026-11-27)


### Features

* **accounts:** launch accounts through legion without per-account shortcuts ([#110](https://github.com/BlackGad/ps-legion-marketplace/issues/110)) ([3716e2d](https://github.com/BlackGad/ps-legion-marketplace/commit/3716e2dd22e0cf01a74a41a7e7be1720f56d80c5))
* **limits:** show how much of each window is left ([#112](https://github.com/BlackGad/ps-legion-marketplace/issues/112)) ([3ebacb1](https://github.com/BlackGad/ps-legion-marketplace/commit/3ebacb1fb206caf7fc067a2f41426494678b131f))


### Fixes

* drop an unreachable raise and two stale doc lines ([#124](https://github.com/BlackGad/ps-legion-marketplace/issues/124)) ([fbc5e14](https://github.com/BlackGad/ps-legion-marketplace/commit/fbc5e1453bb5f169aa6a3ede4e02e76db693bdfc))
* **lease:** find the agent session from Git Bash on Windows ([#107](https://github.com/BlackGad/ps-legion-marketplace/issues/107)) ([3cd257e](https://github.com/BlackGad/ps-legion-marketplace/commit/3cd257ec963841a73dcfc9ca8cae93cfb229ecae))
* **update:** write generated files with the new version ([#108](https://github.com/BlackGad/ps-legion-marketplace/issues/108)) ([a3660da](https://github.com/BlackGad/ps-legion-marketplace/commit/a3660da063effdbc2ed0ccb07cb846364f3f8356))


### Documentation

* describe the bootstrap, update and catalog; drop duplicate account verbs ([#120](https://github.com/BlackGad/ps-legion-marketplace/issues/120)) ([326e974](https://github.com/BlackGad/ps-legion-marketplace/commit/326e9742137e7ca441f6877bba2e13dd13c5e90e))
* one home per rule in the skills; trim the reference to what is true now ([#122](https://github.com/BlackGad/ps-legion-marketplace/issues/122)) ([3f7897d](https://github.com/BlackGad/ps-legion-marketplace/commit/3f7897d87407791fc3def00aed96ddcf63b5cc2d))
* **overseer:** read the owner notes again before each launch and review ([#111](https://github.com/BlackGad/ps-legion-marketplace/issues/111)) ([75473de](https://github.com/BlackGad/ps-legion-marketplace/commit/75473de8f90678d184ea261ee4e4a4712064c47e))


### Refactoring

* **installer:** typed tools catalog; honour registered account commands ([#114](https://github.com/BlackGad/ps-legion-marketplace/issues/114)) ([35d07a8](https://github.com/BlackGad/ps-legion-marketplace/commit/35d07a89cbf4db2610949db55036b6538ec52524))
* **install:** uninstall through the tools' own commands and a system shell delete ([#118](https://github.com/BlackGad/ps-legion-marketplace/issues/118)) ([a3853a1](https://github.com/BlackGad/ps-legion-marketplace/commit/a3853a19d0b86d0fa12c71ba3f6d02aa4d1e00bf))
* **python:** one persisted-file lifecycle; fix installer findings ([#113](https://github.com/BlackGad/ps-legion-marketplace/issues/113)) ([19538b0](https://github.com/BlackGad/ps-legion-marketplace/commit/19538b0341f629f598a3c3750893baa22c64ec98))
* **python:** purification fixes from the milestone 5 review ([#121](https://github.com/BlackGad/ps-legion-marketplace/issues/121)) ([244226a](https://github.com/BlackGad/ps-legion-marketplace/commit/244226a64dec842eb2461741761ade14a38d2a31))
* **python:** trim overseer sessions, dry runs and unread settings ([#119](https://github.com/BlackGad/ps-legion-marketplace/issues/119)) ([d6f5883](https://github.com/BlackGad/ps-legion-marketplace/commit/d6f5883222301d9967ff256a95b6b17cb55a65b9))


### Tests

* drop dead fixtures and duplicate tests; fence sockets in pytest ([#123](https://github.com/BlackGad/ps-legion-marketplace/issues/123)) ([27dca5b](https://github.com/BlackGad/ps-legion-marketplace/commit/27dca5b695fb503e4c2da3a07964748e33b07543))
* **install:** cover the dry-run overseer and the remote bootstrap ([#117](https://github.com/BlackGad/ps-legion-marketplace/issues/117)) ([8277be1](https://github.com/BlackGad/ps-legion-marketplace/commit/8277be156cdf81ed6fa359cb2285d7425c72d544))
* **python:** audit what the plugin and the app copy ship ([#116](https://github.com/BlackGad/ps-legion-marketplace/issues/116)) ([ce75789](https://github.com/BlackGad/ps-legion-marketplace/commit/ce757891069b3ea838ac73a47c247a89d57c13f5))

## [0.18.0](https://github.com/BlackGad/ps-legion-marketplace/compare/v0.17.0...v0.18.0) (2026-11-26)


### Features

* **hook:** run session startup in the installed environment ([#94](https://github.com/BlackGad/ps-legion-marketplace/issues/94)) ([31fa4da](https://github.com/BlackGad/ps-legion-marketplace/commit/31fa4da8cec27f8dc7fad3f4f2afa05dc7e383d3))
* **mcp:** expose status and limits over stdio ([#89](https://github.com/BlackGad/ps-legion-marketplace/issues/89)) ([26f9ce8](https://github.com/BlackGad/ps-legion-marketplace/commit/26f9ce8c4879cf88dae87145de9ffc565a6b7a01))
* **python:** typed status and limits services with JSON output ([#86](https://github.com/BlackGad/ps-legion-marketplace/issues/86)) ([111b886](https://github.com/BlackGad/ps-legion-marketplace/commit/111b88645b677dd3e4b4de16e2e8641ad89587dd))


### Fixes

* **cli:** list every account for a bare legion limits ([#106](https://github.com/BlackGad/ps-legion-marketplace/issues/106)) ([3e80cbb](https://github.com/BlackGad/ps-legion-marketplace/commit/3e80cbb66e26b637301a5cf7c2199823c3c84912))
* **lease:** never record the Codex app-server as the owner ([#97](https://github.com/BlackGad/ps-legion-marketplace/issues/97)) ([476f10a](https://github.com/BlackGad/ps-legion-marketplace/commit/476f10a9bc0059dbe3a9b04965e4c3190c8bac32))
* **legion:** own pending results through resolution ([#91](https://github.com/BlackGad/ps-legion-marketplace/issues/91)) ([cd2cb9d](https://github.com/BlackGad/ps-legion-marketplace/commit/cd2cb9dcf501434e61f520cc1025bb27a96b351a))
* **mcp:** cancel tool calls at the boundary with psutil ([#98](https://github.com/BlackGad/ps-legion-marketplace/issues/98)) ([0f195ce](https://github.com/BlackGad/ps-legion-marketplace/commit/0f195ce2ae21419020ef613b10d56a30718be7e8))
* **mcp:** register the MCP server where Codex reads it ([#102](https://github.com/BlackGad/ps-legion-marketplace/issues/102)) ([2459764](https://github.com/BlackGad/ps-legion-marketplace/commit/24597645768c3fd34323a1128ceca787c3e3cba4))
* **overseer:** keep watch on pending results per tool ([#96](https://github.com/BlackGad/ps-legion-marketplace/issues/96)) ([2070ab8](https://github.com/BlackGad/ps-legion-marketplace/commit/2070ab8294ea526cd5a75f558c2d077e7db46d50))
* **overseer:** select independent agents by task ([#92](https://github.com/BlackGad/ps-legion-marketplace/issues/92)) ([c4e2a2a](https://github.com/BlackGad/ps-legion-marketplace/commit/c4e2a2a9e6cf44f4a8bebbeb001868b5af68f14b))
* **overseer:** trim routing and Telegram voice rules ([#100](https://github.com/BlackGad/ps-legion-marketplace/issues/100)) ([d377896](https://github.com/BlackGad/ps-legion-marketplace/commit/d37789641db31d756c5dd09eb4bd86da5e5b7406))
* **telegram:** honor owner voice and format ([#93](https://github.com/BlackGad/ps-legion-marketplace/issues/93)) ([0e08c19](https://github.com/BlackGad/ps-legion-marketplace/commit/0e08c197ce237efa606cda27cf5be74ef3867d5c))


### Refactoring

* **python:** group runtime modules by package ([#88](https://github.com/BlackGad/ps-legion-marketplace/issues/88)) ([6b029ac](https://github.com/BlackGad/ps-legion-marketplace/commit/6b029acfe6a3d80c9c568a3eaf084009606e3c92))
* **python:** one home for each generic job ([#105](https://github.com/BlackGad/ps-legion-marketplace/issues/105)) ([8ac472c](https://github.com/BlackGad/ps-legion-marketplace/commit/8ac472c066fc3603173c8efa1411fafe978919f1))
* **python:** use httpx, filelock and click for generic jobs ([#104](https://github.com/BlackGad/ps-legion-marketplace/issues/104)) ([ae2a4a4](https://github.com/BlackGad/ps-legion-marketplace/commit/ae2a4a4d283b6cf0a3e9805b761ac3873adb9e1a))
* **python:** use psutil for process parts and clean the launch environment ([#101](https://github.com/BlackGad/ps-legion-marketplace/issues/101)) ([892a705](https://github.com/BlackGad/ps-legion-marketplace/commit/892a7052f2d6211b74f281e2e4d3c695c1559845))
* **settings:** generate the schema files from the models ([#103](https://github.com/BlackGad/ps-legion-marketplace/issues/103)) ([27ff5df](https://github.com/BlackGad/ps-legion-marketplace/commit/27ff5dfb50fd0d922a8f5774b6942d06cd7c3259))


### Tests

* **integration:** prove the first update from 0.17.0 ([#99](https://github.com/BlackGad/ps-legion-marketplace/issues/99)) ([7e54cc6](https://github.com/BlackGad/ps-legion-marketplace/commit/7e54cc6f990b93849bd4fc9d2b62143f897cc67b))
* **python:** fence the real user PATH in every test ([#95](https://github.com/BlackGad/ps-legion-marketplace/issues/95)) ([a4028ce](https://github.com/BlackGad/ps-legion-marketplace/commit/a4028ce7c5f71004210990477236dc96f702b22d))

## [0.17.0](https://github.com/BlackGad/ps-legion-marketplace/compare/v0.16.0...v0.17.0) (2026-11-25)


### Features

* **python:** setup and add in Python ([#82](https://github.com/BlackGad/ps-legion-marketplace/issues/82)) ([0989a8c](https://github.com/BlackGad/ps-legion-marketplace/commit/0989a8c63d855eeb80c0a2730739824bb9ef21fe))
* **python:** the installer lifecycle in Python ([#80](https://github.com/BlackGad/ps-legion-marketplace/issues/80)) ([d970044](https://github.com/BlackGad/ps-legion-marketplace/commit/d97004428ced416b13ab5850cec3bbe1dd2dc31e))
* **python:** the overseer launch in Python ([#78](https://github.com/BlackGad/ps-legion-marketplace/issues/78)) ([a91899b](https://github.com/BlackGad/ps-legion-marketplace/commit/a91899bdd5f0dcafd1a9cbdf45490bcaf901050d))
* **python:** tool installs in Python ([#77](https://github.com/BlackGad/ps-legion-marketplace/issues/77)) ([5217d8f](https://github.com/BlackGad/ps-legion-marketplace/commit/5217d8f24d35f5d7481f842210140a0662adac4a))


### Fixes

* **install:** resolve milestone four release findings ([#85](https://github.com/BlackGad/ps-legion-marketplace/issues/85)) ([55704fd](https://github.com/BlackGad/ps-legion-marketplace/commit/55704fdbc2d0fda5e0d3f4ddc42edfa66ca09c1f))
* **lease:** keep a same-tick parent in the process chain ([#81](https://github.com/BlackGad/ps-legion-marketplace/issues/81)) ([30e9a0a](https://github.com/BlackGad/ps-legion-marketplace/commit/30e9a0a05e6265a6e16ca2e172c9d0f8f672b52e))
* **lease:** skip the legion launcher when finding the session ([#75](https://github.com/BlackGad/ps-legion-marketplace/issues/75)) ([cd8585c](https://github.com/BlackGad/ps-legion-marketplace/commit/cd8585cf1cf28cd651637f997f18345ea4fc3381))


### Tests

* **integration:** the integration runner in Python ([#83](https://github.com/BlackGad/ps-legion-marketplace/issues/83)) ([252779a](https://github.com/BlackGad/ps-legion-marketplace/commit/252779a73ec276699fad6c207f16ecf93bd65fcb))
* tolerate same-tick process starts in the chain test ([30e9a0a](https://github.com/BlackGad/ps-legion-marketplace/commit/30e9a0a05e6265a6e16ca2e172c9d0f8f672b52e))

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
