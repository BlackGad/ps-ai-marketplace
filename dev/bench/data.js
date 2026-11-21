window.BENCHMARK_DATA = {
  "lastUpdate": 1795291734181,
  "repoUrl": "https://github.com/BlackGad/ps-ai-marketplace",
  "entries": {
    "integration timings": [
      {
        "commit": {
          "author": {
            "email": "ztBlackGad@gmail.com",
            "name": "Volodymyr Shkolka",
            "username": "BlackGad"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "8bdb4096a868b75dc9350f691a603083fc4f4134",
          "message": "feat: releases, CI and integration runs (#17)\n\n* docs: release and conventional commit rules\n\n* ci: add release-please config starting at 0.6.0\n\n* test: check workflow pins, permissions and timeouts\n\n* test: write a JUnit report from the test runner\n\n* test: benchmark JSON for integration timings\n\n* ci: release workflow with release-please and a tested release PR\n\n* feat(setup): pass -Source through to the installer\n\n* test: integration runner for install, setup and uninstall\n\n* ci: run unit tests on three systems behind one gate check\n\n* fix: unit tests pass on the GitHub Windows runner\n\n* test: use the portable temp folder instead of the Windows TEMP variable\n\n* fix: tolerate clock jitter when matching a lease owner's start time on Linux and macOS\n\n* test: keep chmod reachable when tests narrow PATH, and set modes without it\n\n* test: remove hidden dot-files with -Force on Unix\n\n* test: leave out Windows-only options and Windows path forms on Unix\n\n* fix: use the start-time tolerance in the lease state check\n\n* ci: read-only reusable tests and a pinned release PR head\n\n* fix: put -- before the mode in chmod for macOS; resolve the temp folder in link-sensitive tests\n\n* test: integration runner fails real install errors and checks account folders\n\n* ci: integration suite on every pull request, with timing trend\n\n* docs: status and release badges\n\n* fix(install): support a fresh Codex home\n\n* fix(install): make winget non-interactive\n\n* test: sanitize JUnit output and disable colour\n\n* fix: detect live Copilot installs and retain logs\n\n* fix: ignore CLI runtime files in repeat checks\n\n* test: compare parsed CLI versions in integration repeats\n\n* fix: probe the Windows PowerShell version\n\n* fix(install): tolerate a missing console\n\n* ci: allow source fallback for all main runs\n\n* docs: remove legion co-author requirement\n\n* docs: explain release PR status refresh",
          "timestamp": "2026-11-21T00:25:03+02:00",
          "tree_id": "f625598bbde617cfcbc8923596027f7e9a5c8fe9",
          "url": "https://github.com/BlackGad/ps-ai-marketplace/commit/8bdb4096a868b75dc9350f691a603083fc4f4134"
        },
        "date": 1795213694845,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 13.2660365,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 0.8559877,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 17.3008438,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.7137636,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 23.1558299,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 0.9491856,
            "unit": "s"
          },
          {
            "name": "windows / install-ps-ai",
            "value": 13.1451584,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-ps-ai (repeat)",
            "value": 3.7589301,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 18.0692042,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 2.8091643,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 4.4754478,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 0.9373945,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 0.6030033,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.3895756,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 1.7053421,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 0.9339441,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 1.7760656,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 0.9341814,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 15.8460611,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 6.8583138,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 11.6871407,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 1.1604349,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 7.1451771,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 1.2766407,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 5.7849102,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 1.2896039,
            "unit": "s"
          },
          {
            "name": "macos / install-ps-ai",
            "value": 10.128621,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-ps-ai (repeat)",
            "value": 6.1138088,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 14.7523201,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 2.4195875,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 4.2482478,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 1.1527012,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.6631403,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.4260051,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 2.2986549,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 1.6052819,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 3.1529016,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 1.7523802,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 21.8996545,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 7.2002477,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 8.9297003,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.7481947,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 5.610914,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.6656646,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 4.0337302,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.7862594,
            "unit": "s"
          },
          {
            "name": "linux / install-ps-ai",
            "value": 8.1998394,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-ps-ai (repeat)",
            "value": 3.5008037,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 12.141022,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 2.9009917,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 5.8041766,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 0.9333322,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.5910963,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.3189063,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 0.9775425,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.5772931,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 0.9969896,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.5678316,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 12.7411827,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 5.0980871,
            "unit": "s"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "41898282+github-actions[bot]@users.noreply.github.com",
            "name": "github-actions[bot]",
            "username": "github-actions[bot]"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "a415c85fbf0b12b044d8c5a7868f499f910a4942",
          "message": "chore(main): release 0.7.0 (#19)",
          "timestamp": "2026-11-21T00:52:41+02:00",
          "tree_id": "37d6166b4e1a968d345a03998184d6f169cab1f5",
          "url": "https://github.com/BlackGad/ps-ai-marketplace/commit/a415c85fbf0b12b044d8c5a7868f499f910a4942"
        },
        "date": 1795215387763,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 14.6249702,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 1.2255932,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 19.4684557,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 1.0790462,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 16.8950778,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.6416424,
            "unit": "s"
          },
          {
            "name": "windows / install-ps-ai",
            "value": 16.1031121,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-ps-ai (repeat)",
            "value": 5.7551168,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 24.1454754,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 4.3180109,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 6.9477622,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 1.5263426,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 1.009498,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.6228039,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 2.6236222,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.5256933,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 2.6662843,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.3318349,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 22.5503282,
            "unit": "s",
            "extra": "claude 2.1.329, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 9.2097292,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 13.1902107,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 0.7476528,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 5.268877,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 1.0232273,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 4.9349908,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 1.0960057,
            "unit": "s"
          },
          {
            "name": "macos / install-ps-ai",
            "value": 10.1059945,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-ps-ai (repeat)",
            "value": 4.2163271,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 15.4402902,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 3.2851601,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 4.3754612,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 1.0825128,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.6459978,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.3934778,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 2.1474693,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 1.2842708,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 2.4998588,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 1.397449,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 17.8299012,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 6.7213768,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 8.9460649,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.8817559,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 6.5279941,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.8216476,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 5.2838857,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.9758606,
            "unit": "s"
          },
          {
            "name": "linux / install-ps-ai",
            "value": 9.0426413,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-ps-ai (repeat)",
            "value": 4.0795895,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 14.7798922,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 3.5680293,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 4.298333,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 1.1734328,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.9471434,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.5300982,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 1.5925592,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.6714562,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 1.1814129,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.6544598,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 15.021154,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 6.0444958,
            "unit": "s"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "ztBlackGad@gmail.com",
            "name": "Volodymyr Shkolka",
            "username": "BlackGad"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "ede19d2ab4640d26d27d9ca5c694003463986a92",
          "message": "docs: add release summary to the GitHub Release, not the release pull request (#22)",
          "timestamp": "2026-11-21T09:57:44+02:00",
          "tree_id": "1d99d93c49fbd013902bfa91e697e81b387a645c",
          "url": "https://github.com/BlackGad/ps-ai-marketplace/commit/ede19d2ab4640d26d27d9ca5c694003463986a92"
        },
        "date": 1795248025905,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 12.0683252,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 0.6974148,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 15.9308223,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.6283036,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 16.0604148,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 0.8392451,
            "unit": "s"
          },
          {
            "name": "windows / install-ps-ai",
            "value": 11.6080133,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-ps-ai (repeat)",
            "value": 3.6077883,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 15.8171273,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 2.5649075,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 4.0245073,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 0.8328903,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 0.5343042,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.3295825,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 1.4378028,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 0.8841834,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 1.6306262,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 0.8172071,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 14.7817774,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 5.7337456,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 13.9619595,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 1.2916004,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 10.4067345,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 1.357145,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 6.9032218,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 1.4938887,
            "unit": "s"
          },
          {
            "name": "macos / install-ps-ai",
            "value": 11.7868812,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-ps-ai (repeat)",
            "value": 5.1374774,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 12.9472869,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 2.8032821,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 3.1139198,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 0.7222247,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.4639744,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.2943609,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 1.66973,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 0.9412222,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 1.8002179,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 0.8018202,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 14.585799,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 6.1432556,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 13.096477,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.5113328,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 4.8240592,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.5505604,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 3.756491,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.662671,
            "unit": "s"
          },
          {
            "name": "linux / install-ps-ai",
            "value": 7.5996485,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-ps-ai (repeat)",
            "value": 2.8798465,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 10.1941175,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 2.5687447,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 3.0644701,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 0.8360005,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.479943,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.2397686,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 0.7374983,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.4244515,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 0.7398302,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.4271829,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 10.9074721,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 4.3065518,
            "unit": "s"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "ztBlackGad@gmail.com",
            "name": "Volodymyr Shkolka",
            "username": "BlackGad"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "1fb9fcd7129b53b10026fe5c1691b2d5c0364176",
          "message": "feat: easy install, update, uninstall and overseer restore (#24)\n\n* fix(launcher): bare legion start repeats the last launch\n\n* fix(launcher): preserve restart settings\n\n* feat(overseer): set up the repository and ask which account leads\n\n* refactor(install): ship the installer inside the plugin\n\n* feat(overseer): resume the last overseer conversation\n\n* feat(install): install the latest release by default\n\n* feat(install): update follows its track\n\n* fix(refresh): create missing owner commands\n\n* feat(legion): bare legion launches; add pick, update and uninstall\n\n* ci(release): move the stable branch to each release\n\n* feat(install): install creates the legion command\n\n* fix(uninstall): move commands only to a copy that provides them\n\n* docs: one-word lifecycle commands\n\n* fix(overseer): stop with an error when setup cannot be asked\n\n* fix: review round for easy lifecycle\n\n* fix(uninstall): stay inside the chosen home and exit cleanly from legion.cmd",
          "timestamp": "2026-11-21T16:22:54+02:00",
          "tree_id": "d3a6981438889f60495f713f542357b62874e053",
          "url": "https://github.com/BlackGad/ps-ai-marketplace/commit/1fb9fcd7129b53b10026fe5c1691b2d5c0364176"
        },
        "date": 1795271214002,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 15.6111933,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 1.1907207,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 19.1524444,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 1.10416,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 17.3485281,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.4233655,
            "unit": "s"
          },
          {
            "name": "windows / install-ps-ai",
            "value": 25.5254883,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-ps-ai (repeat)",
            "value": 9.6848479,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 21.6186576,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 5.3708207,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 6.8778771,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 1.4651744,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 0.9397292,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.5712112,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 2.497243,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.5097643,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 2.5895306,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.4086015,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 24.255961,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 6.4270157,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 10.0966671,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 0.7118101,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 6.3206684,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 0.7494297,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 4.3084514,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 0.8849065,
            "unit": "s"
          },
          {
            "name": "macos / install-ps-ai",
            "value": 10.062697,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-ps-ai (repeat)",
            "value": 5.9430071,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 14.2789306,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 2.7120891,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 3.7095802,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 0.9409835,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.6056449,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.3221069,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 1.5884758,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 1.3644901,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 2.0748097,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 1.2262289,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 13.851826,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 3.2484496,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 8.6488882,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 1.2559346,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 6.6617277,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.903848,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 5.2470013,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.9875396,
            "unit": "s"
          },
          {
            "name": "linux / install-ps-ai",
            "value": 11.2873771,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-ps-ai (repeat)",
            "value": 6.5614856,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 14.4676081,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 3.5529549,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 4.257479,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 1.2225281,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.7058351,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.3829667,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 1.1271224,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.6519311,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 1.1573807,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.6394282,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 15.1816263,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 4.3605992,
            "unit": "s"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "41898282+github-actions[bot]@users.noreply.github.com",
            "name": "github-actions[bot]",
            "username": "github-actions[bot]"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "fc5c19b873a3b1ae1dafdffce62b4a09d5466a5d",
          "message": "chore(main): release 0.8.0 (#23)",
          "timestamp": "2026-11-21T16:29:40+02:00",
          "tree_id": "9ef1400ff03b4fa3b8e541a505048d6f2300d2f0",
          "url": "https://github.com/BlackGad/ps-ai-marketplace/commit/fc5c19b873a3b1ae1dafdffce62b4a09d5466a5d"
        },
        "date": 1795271600383,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 14.704063,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 1.2004612,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 19.8322828,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 1.0542081,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 17.324797,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.5754483,
            "unit": "s"
          },
          {
            "name": "windows / install-ps-ai",
            "value": 23.2400341,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-ps-ai (repeat)",
            "value": 9.4499657,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 19.6235141,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 4.2846578,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 6.4411365,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 1.4039999,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 0.8989886,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.551793,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 2.3468258,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.3788114,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 2.5174171,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.3682035,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 23.8566199,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 6.2644064,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 13.9621653,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 1.0810619,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 7.6938347,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 1.0797425,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 6.0057102,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 1.2722307,
            "unit": "s"
          },
          {
            "name": "macos / install-ps-ai",
            "value": 14.9860343,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-ps-ai (repeat)",
            "value": 8.5040017,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 18.3215933,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 4.4247995,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 7.1241724,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 2.1188104,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.9817627,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.626767,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 3.0598627,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 2.0216652,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 3.4024975,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 1.9586147,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 24.0449811,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 4.758167,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 11.5268759,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.4855668,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 4.5706269,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.5742684,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 3.7094029,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.6249023,
            "unit": "s"
          },
          {
            "name": "linux / install-ps-ai",
            "value": 9.1698869,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-ps-ai (repeat)",
            "value": 4.3639719,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 10.12092,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 2.5011208,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 3.1077681,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 0.8108784,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.465343,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.2274878,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 0.6985916,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.39465,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 0.7048247,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.396497,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 10.8818783,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 2.8708087,
            "unit": "s"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "ztBlackGad@gmail.com",
            "name": "Volodymyr Shkolka",
            "username": "BlackGad"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "dd1f1e24ff3b8bec7902c00fb609f3ddbf22a5e6",
          "message": "fix(install): keep account launchers across reinstall (#25)\n\n* fix(install): keep account launchers across reinstall\n\n* test(integration): cover kept and restored account launchers",
          "timestamp": "2026-11-21T17:53:26+02:00",
          "tree_id": "38cc6744988b68bfb91fc708b549608dab0dd1a8",
          "url": "https://github.com/BlackGad/ps-ai-marketplace/commit/dd1f1e24ff3b8bec7902c00fb609f3ddbf22a5e6"
        },
        "date": 1795276652600,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 13.471084,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 0.9477401,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 18.6805646,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.8319861,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 14.4865307,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.1137783,
            "unit": "s"
          },
          {
            "name": "windows / install-ps-ai",
            "value": 20.8019186,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-ps-ai (repeat)",
            "value": 7.5357058,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 15.8656092,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 3.4536001,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 5.3647209,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 1.1284611,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 0.7201213,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.4403123,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 1.8973385,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.1330214,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 2.0900218,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.0935617,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 19.4430863,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 5.1424448,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 19.323143,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 12.3037721,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 13.1056897,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 12.1527715,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 11.2485898,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 0.9590712,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 7.2245344,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 1.9383214,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 7.0340427,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 1.8987168,
            "unit": "s"
          },
          {
            "name": "macos / install-ps-ai",
            "value": 14.8323012,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-ps-ai (repeat)",
            "value": 8.5746035,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 19.2175031,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 4.5620522,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 5.8944492,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 1.2149962,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.5315675,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.3243903,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 1.8234059,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 0.9247255,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 1.8698497,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 1.0597845,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 24.5629252,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 5.0409414,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 18.9715162,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 14.7144979,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 16.3806525,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 13.3258989,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 9.4165183,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.7358873,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 4.3584859,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.4991856,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 3.0097762,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.6043901,
            "unit": "s"
          },
          {
            "name": "linux / install-ps-ai",
            "value": 8.4802299,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-ps-ai (repeat)",
            "value": 4.2336627,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 9.6799471,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 2.0960203,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 2.8510291,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 0.6717932,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.4352046,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.2477984,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 0.7482473,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.4296274,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 0.7665622,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.4263448,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 9.9642057,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 2.7568189,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 10.323892,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 7.1407999,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 7.6740251,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 7.7585647,
            "unit": "s"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "ztBlackGad@gmail.com",
            "name": "Volodymyr Shkolka",
            "username": "BlackGad"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "cd40a91dd47d5f9ade37e45a93919045ae8f9de7",
          "message": "feat(install): add uninstall purge that removes every ps-ai trace (#27)\n\n* fix(install): keep account launchers across reinstall\n\n* test(integration): cover kept and restored account launchers\n\n* feat(install): add uninstall purge that removes every ps-ai trace\n\n* refactor(install): simplify purge and cover it in integration\n\n* fix(install): purge settings scan independent of line endings",
          "timestamp": "2026-11-21T18:31:19+02:00",
          "tree_id": "a1645714857cbcc9b91022c73810bb701a687d04",
          "url": "https://github.com/BlackGad/ps-ai-marketplace/commit/cd40a91dd47d5f9ade37e45a93919045ae8f9de7"
        },
        "date": 1795279024138,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 15.4909517,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 1.2060389,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 19.5714917,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 1.0574709,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 18.4595094,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.5889702,
            "unit": "s"
          },
          {
            "name": "windows / install-ps-ai",
            "value": 36.1252663,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-ps-ai (repeat)",
            "value": 10.7929531,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 20.0904472,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 4.4169331,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 6.6300244,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 1.4485415,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 0.9253433,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.5527181,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 2.4012853,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.3903386,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 2.6073663,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.3455542,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 22.6324772,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 6.2392653,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 25.0913881,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 16.1080613,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 17.742217,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 15.9918879,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 23.7392393,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 6.6337952,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 12.520192,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 0.6658982,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 6.2560812,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 1.4409769,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 8.4184304,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 2.0533509,
            "unit": "s"
          },
          {
            "name": "macos / install-ps-ai",
            "value": 22.1401624,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-ps-ai (repeat)",
            "value": 10.3786035,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 19.6692463,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 3.8414715,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 4.6086722,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 1.5954037,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 1.04218,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.7027511,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 2.8184454,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 1.5727257,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 2.0679437,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 2.0062021,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 21.9196495,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 5.1770674,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 24.026892,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 15.113373,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 17.8788937,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 18.1873507,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 23.5582574,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 8.0189611,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 11.8405373,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.5649808,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 4.839679,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.572685,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 4.0621668,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.6705071,
            "unit": "s"
          },
          {
            "name": "linux / install-ps-ai",
            "value": 9.6310306,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-ps-ai (repeat)",
            "value": 4.6428662,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 10.3618972,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 2.6785215,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 3.1866859,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 0.8622127,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.4946043,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.2446345,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 0.7560403,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.4281072,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 0.7487627,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.4294273,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 11.5404731,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 3.1596887,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 11.4984163,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 7.9518091,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 8.6799211,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 7.9388359,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 11.7209422,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 3.4954203,
            "unit": "s"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "41898282+github-actions[bot]@users.noreply.github.com",
            "name": "github-actions[bot]",
            "username": "github-actions[bot]"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "de0e596c5bf81d0fc1838b843fc14ab158bec88a",
          "message": "chore(main): release 0.9.0 (#26)",
          "timestamp": "2026-11-21T22:04:07+02:00",
          "tree_id": "71e75d8fcaa2f998f4506c02d59a0e5875ca7251",
          "url": "https://github.com/BlackGad/ps-ai-marketplace/commit/de0e596c5bf81d0fc1838b843fc14ab158bec88a"
        },
        "date": 1795291733373,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 13.2328589,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 0.8958055,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 17.0467914,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.8108779,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 15.9510388,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.2601227,
            "unit": "s"
          },
          {
            "name": "windows / install-ps-ai",
            "value": 37.1777614,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-ps-ai (repeat)",
            "value": 8.4338717,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 16.0626917,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 3.3229393,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 5.2694506,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 1.0390463,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 0.6999614,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.4358505,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 1.8781998,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.0439855,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 1.9661882,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.0201816,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 17.1403392,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 4.8881372,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 17.821362,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 12.1272795,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 13.0831055,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 11.8777498,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 17.6699799,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 4.9800469,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 11.869958,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 0.7528844,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 5.4857297,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 0.8443039,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 4.5862857,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 1.1430134,
            "unit": "s"
          },
          {
            "name": "macos / install-ps-ai",
            "value": 11.6116592,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-ps-ai (repeat)",
            "value": 5.6201222,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 11.8528841,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 2.3916752,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 3.7084228,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 0.8577929,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.5660777,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.3589813,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 1.8291324,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 1.1714817,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 1.8632409,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 0.82494,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 16.4920313,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 4.0590312,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 16.3212567,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 10.40112,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 11.1087755,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 10.0699228,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 15.4026854,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 4.4406081,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 14.6638202,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.5314157,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 4.7909135,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.5723544,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 3.7957631,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.6705961,
            "unit": "s"
          },
          {
            "name": "linux / install-ps-ai",
            "value": 10.1440203,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-ps-ai (repeat)",
            "value": 4.7547424,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 10.4610906,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 2.6717528,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 3.1137758,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 0.8820485,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.5045965,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.2483077,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 0.7561047,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.4261525,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 0.7498729,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.4304621,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 11.2558867,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 3.2404984,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 11.2878145,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 8.1836912,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 8.9100366,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 8.1583665,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 11.5713062,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 3.5822682,
            "unit": "s"
          }
        ]
      }
    ]
  }
}