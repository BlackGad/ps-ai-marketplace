window.BENCHMARK_DATA = {
  "lastUpdate": 1795420391667,
  "repoUrl": "https://github.com/BlackGad/ps-legion-marketplace",
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
          "id": "92aedc50a9553ebc67e834e27ece664aadd87b54",
          "message": "feat!: rename ps-ai to legion (#28)\n\n* refactor: rename internal PsAi names to Legion\n\n* feat: one legion command\n\n* feat: legion member role variables\n\n* refactor: rename skills and scripts to legion-*\n\n* feat: legion names for owner files\n\n* test: fix integration rules heading and unix uninstall home check\n\n* test: resolve the fenced test home to its real path\n\n* feat!: plugin legion in ps-legion-marketplace\n\nBREAKING CHANGE: uninstall the previous plugin before installing legion@ps-legion-marketplace. No plugin migration is provided.\n\n* refactor!: drop pre-legion compatibility\n\nBREAKING CHANGE: pre-legion setups must be uninstalled and set up\nagain. Migration paths and old-name fallbacks are no longer supported.",
          "timestamp": "2026-11-21T23:05:08+02:00",
          "tree_id": "2d212d4a8265c4076b6d7a45bc200a73f9ac1fe0",
          "url": "https://github.com/BlackGad/ps-ai-marketplace/commit/92aedc50a9553ebc67e834e27ece664aadd87b54"
        },
        "date": 1795295385066,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 11.9720461,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 0.8681203,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 21.6103586,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.8233884,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 15.5196077,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 0.9960474,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 18.0812181,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 6.484492,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 14.335346,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 2.8897064,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 4.6354958,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 0.946052,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 0.6527305,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.3896894,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 1.8424819,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.1192916,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 2.1143448,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.0735905,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 18.9252887,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 4.8750743,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 15.9650722,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 10.4006322,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 11.8121771,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 11.2536908,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 17.1150338,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 4.4143792,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 16.2300065,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 1.3474404,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 8.439231,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 1.2322151,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 6.3205976,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 1.4578995,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 14.6536516,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 6.9401667,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 16.0118252,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 3.597508,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 4.8926649,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 1.4212614,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.7325632,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.4108307,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 1.9616075,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 1.1085813,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 2.6914419,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 1.3791752,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 20.3074221,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 5.8772186,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 20.8572248,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 12.5357865,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 17.5297822,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 20.721691,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 23.9724243,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 6.282196,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 12.8468004,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.6259803,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 4.7098975,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.5493581,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 3.7126499,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.6648159,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 8.2313436,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 4.7021617,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 10.4062223,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 2.6544626,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 2.9583467,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 0.8532693,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.5049316,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.2500288,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 0.7704617,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.4391414,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 0.7716325,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.430426,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 11.3735752,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 3.4563428,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 11.5206938,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 8.2328662,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 9.0039194,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 8.1663733,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 11.684354,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 3.6819524,
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
          "id": "2eba64063f5437f1d742699f910fa0e6d0a13638",
          "message": "chore(main): release 0.10.0 (#29)",
          "timestamp": "2026-11-21T23:11:04+02:00",
          "tree_id": "d018b96c27154f21f12f97e91445c8d0d2ecf4b6",
          "url": "https://github.com/BlackGad/ps-legion-marketplace/commit/2eba64063f5437f1d742699f910fa0e6d0a13638"
        },
        "date": 1795295795880,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 14.8704757,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 1.1227347,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 18.317487,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.9978065,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 19.5115626,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.5058296,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 23.6628821,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 9.1358563,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 19.3303078,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 3.9035738,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 6.3037187,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 1.26939,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 0.8354825,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.480054,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 2.1746827,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.3478801,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 2.4571504,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.2688756,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 22.4204191,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 6.9510902,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 23.9965976,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 16.5266522,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 16.3516594,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 15.2055865,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 23.6794888,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 6.7956256,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 7.7958658,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 1.0126552,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 5.6467691,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 0.6981139,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 4.7453234,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 0.9994648,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 10.9584698,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 6.1096855,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 11.5042097,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 3.2279777,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 3.327115,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 0.8840362,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.6114941,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.3956178,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 1.8257678,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 1.5432859,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 1.9614102,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 0.8923357,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 13.8286663,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 4.6844002,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 12.5289008,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 8.8165579,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 9.2178898,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 9.1510201,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 14.0271268,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 4.3157742,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 13.2162498,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.582306,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 4.7003358,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.5780002,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 3.7463328,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.7043858,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 10.2529024,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 4.7342619,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 10.3866193,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 2.6383171,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 2.9877438,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 0.8725514,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.5262918,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.2586537,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 0.7757606,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.4346384,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 0.7567183,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.4438377,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 11.4473257,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 3.3089983,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 11.47418,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 8.1677957,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 8.9297827,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 8.2717473,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 11.7416693,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 3.5105832,
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
          "id": "258fb6fe23c5373a1a222df99044d4cee57f3600",
          "message": "fix: point links and defaults to ps-legion-marketplace (#30)",
          "timestamp": "2026-11-21T23:52:59+02:00",
          "tree_id": "3e98035825d84df565a6304c74023d489a306f89",
          "url": "https://github.com/BlackGad/ps-legion-marketplace/commit/258fb6fe23c5373a1a222df99044d4cee57f3600"
        },
        "date": 1795298318550,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 13.8466428,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 1.1652575,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 18.8848661,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 1.0076676,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 18.4697572,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.5719577,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 32.0128531,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 9.3485389,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 19.3728438,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 4.0649539,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 6.1838853,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 1.2857179,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 0.8220033,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.5313239,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 2.3344638,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.3768453,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 2.5538152,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.3434077,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 24.5953425,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 6.4221228,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 23.2544607,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 16.7212325,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 17.233604,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 16.0559003,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 24.6022224,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 6.9948745,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 13.4687997,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 0.9791904,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 10.2493001,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 2.074265,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 5.8760865,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 1.175438,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 14.7504647,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 8.8859902,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 21.3226812,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 3.6433895,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 4.3866962,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 1.318957,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.7406214,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.4302328,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 1.9766556,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 1.1992869,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 2.0442957,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 1.2674198,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 20.0556137,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 5.5753452,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 22.1573056,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 15.0565287,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 22.444151,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 14.5760995,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 17.6305343,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 4.3478405,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 11.0625855,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.6483488,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 4.8840777,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.6160208,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 3.9431317,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.7120058,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 9.4294186,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 4.9429824,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 11.0964824,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 2.7777899,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 3.3627678,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 0.8909834,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.5257722,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.2563734,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 0.8019023,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.4634777,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 0.8039429,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.4601645,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 11.9132848,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 3.3523952,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 12.2259966,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 8.3977946,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 9.1974259,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 8.2854659,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 12.3120881,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 3.6214144,
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
          "id": "f323f766b88a71774df100cd6a937fbb4bfeab1e",
          "message": "feat(setup): allow the overseer to start legion members in Claude (#31)\n\n* feat(setup): allow the overseer to start legion members in Claude\n\n* docs: fix allow rule wording",
          "timestamp": "2026-11-21T23:53:18+02:00",
          "tree_id": "9afaf7ad022075ea5f3cc3ed67034d083820e7bb",
          "url": "https://github.com/BlackGad/ps-legion-marketplace/commit/f323f766b88a71774df100cd6a937fbb4bfeab1e"
        },
        "date": 1795298566644,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 11.4951443,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 0.9350574,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 19.9022946,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.7416007,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 11.9656755,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 0.9159615,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 18.2408573,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 6.2039507,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 13.515196,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 2.7507325,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 4.4797179,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 0.8669273,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 0.608553,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.3802959,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 1.7070524,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 0.998557,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 1.8613317,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 0.945539,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 15.5956313,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 4.2041873,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 16.178795,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 11.0688044,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 11.1983695,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 10.4324356,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 15.8403271,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 4.5078327,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 10.444551,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 1.1536294,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 6.7522246,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 1.0789245,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 6.7615085,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 1.3693944,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 13.8247884,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 7.0862781,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 14.5890165,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 2.9615196,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 3.3168967,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 0.8844027,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.5768008,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.3752803,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 1.6840173,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 1.1110164,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 2.1882912,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 1.2117053,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 18.1817711,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 4.8625687,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 16.8008431,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 16.8432964,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 15.0007144,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 13.2902882,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 16.924028,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 5.5567444,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 13.7916752,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.5632228,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 4.7273415,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.5593644,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 3.9815408,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.689142,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 9.6440025,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 4.6559889,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 10.5245656,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 2.6603777,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 3.1953057,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 0.8580542,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.4913104,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.2413723,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 0.7602376,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.4280995,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 0.7583717,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.4329631,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 11.5599516,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 3.1916974,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 11.5307341,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 7.9837242,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 8.6432368,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 7.8638448,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 11.7018866,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 3.5697024,
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
          "id": "df0fc2903acd67896707a68b969499c580367ffe",
          "message": "feat(hooks): warn when a bound channel is not connected (#33)",
          "timestamp": "2026-11-22T00:08:23+02:00",
          "tree_id": "0516fe96222490ac2caad6d29ef7996a910121df",
          "url": "https://github.com/BlackGad/ps-legion-marketplace/commit/df0fc2903acd67896707a68b969499c580367ffe"
        },
        "date": 1795299148623,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 12.5147826,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 0.7894306,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 15.9647244,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.729896,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 14.7103822,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 0.9248651,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 18.8284226,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 6.6786108,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 13.6543125,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 2.8437856,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 4.635814,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 0.9725646,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 0.6538713,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.4033464,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 1.747461,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.0025965,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 1.9326649,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 0.9792095,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 16.6107926,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 4.3278646,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 15.6806473,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 10.4946008,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 10.884487,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 10.7122923,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 16.1295865,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 4.4360769,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 10.4434018,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 0.7536806,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 5.565654,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 0.717369,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 4.5642868,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 0.8755283,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 9.3654617,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 4.980191,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 10.8240875,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 2.2923795,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 2.9363544,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 0.8267572,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.5269788,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.330289,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 1.3636181,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 0.9973527,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 1.3055468,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 0.8413718,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 13.0381802,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 3.4587871,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 12.3070325,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 8.4247018,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 9.4608578,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 9.6931283,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 17.8143021,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 5.2171544,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 13.2133479,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.9733606,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 6.7984767,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.8648804,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 5.319851,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 1.0349063,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 13.0417613,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 6.8689779,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 15.1130178,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 3.6695664,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 4.4612804,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 1.1692492,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.7234991,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.390543,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 1.16283,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.6825896,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 1.1945061,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.6872636,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 16.0190255,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 4.5611763,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 16.3008252,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 11.6164609,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 12.8198755,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 11.861047,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 16.0582102,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 4.9246859,
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
          "id": "b81f52c867e2ea861c425f8ecded83cba0e3598c",
          "message": "fix(ci): pass the source fallback only on a direct main push (#34)",
          "timestamp": "2026-11-22T00:08:58+02:00",
          "tree_id": "d708edb8d26a80641661768fb3aa5a8187b1f1ec",
          "url": "https://github.com/BlackGad/ps-legion-marketplace/commit/b81f52c867e2ea861c425f8ecded83cba0e3598c"
        },
        "date": 1795299413955,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 13.2321202,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 0.9072188,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 18.0247307,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.8005341,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 13.4862299,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.0643927,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 19.3094921,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 7.2132505,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 15.2661036,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 3.272237,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 10.461249,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 1.0484398,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 0.7019855,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.425936,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 1.7807904,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.0358486,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 1.9416653,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.021347,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 18.704724,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 4.9794584,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 18.5533344,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 12.2749801,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 13.0614711,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 12.1892384,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 18.4258847,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 5.1906196,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 13.3587,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 1.3271841,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 6.2587175,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 0.9911383,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 5.106902,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 1.1561823,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 12.0448528,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 6.6360918,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 14.0561736,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 2.9979017,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 4.0800789,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 0.9661533,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.7598009,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.2870281,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 1.5133088,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 0.7964957,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 1.8065092,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 0.854846,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 17.8326976,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 4.8092824,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 18.6755443,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 15.5596171,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 20.0912763,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 15.05905,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 19.2639756,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 5.5535149,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 12.6626787,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.5701756,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 4.8422877,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.6265209,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 3.7659027,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.6959738,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 9.0683339,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 4.7593687,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 10.4699424,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 2.6724482,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 3.0446726,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 0.8480433,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.4942909,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.2531508,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 0.7562839,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.4317266,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 0.7645604,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.4313697,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 11.5761124,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 3.4804277,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 11.4822218,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 7.9832277,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 8.7733735,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 7.9527648,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 11.6522654,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 3.6146842,
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
          "id": "c66f2c455e5839c843c7abc19c17a9a534a40e3c",
          "message": "chore(main): release 0.11.0 (#32)",
          "timestamp": "2026-11-22T09:05:23+02:00",
          "tree_id": "adc692ebbe6b7238d5f2f609c0994c23bea10ec0",
          "url": "https://github.com/BlackGad/ps-legion-marketplace/commit/c66f2c455e5839c843c7abc19c17a9a534a40e3c"
        },
        "date": 1795331386702,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 9.3734078,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 0.8855947,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 16.1038594,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.7891978,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 16.3632754,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.1303242,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 18.6071125,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 7.3116272,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 15.008558,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 3.1327277,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 4.8668832,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 1.0681069,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 0.6529538,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.4005468,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 1.7008145,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.0236258,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 1.8985775,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.0099391,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 18.3439037,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 4.9435482,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 19.9333417,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 13.1918318,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 13.5473535,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 12.8318778,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 20.3008657,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 5.7487039,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 10.9961024,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 0.6799801,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 6.343732,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 0.8501475,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 4.4325193,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 1.0529349,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 11.812308,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 5.0869596,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 11.589451,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 2.3506767,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 3.172934,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 0.7653628,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.476707,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.2541488,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 1.4625125,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 0.7336031,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 1.5857073,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 0.7833577,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 13.4128632,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 3.5164474,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 14.2886938,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 11.3304528,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 12.6966162,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 10.0264932,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 16.6057051,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 4.6793212,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 13.255423,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.5475421,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 4.8322348,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.5416863,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 3.9745834,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.6659975,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 9.9794749,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 4.6358435,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 10.462113,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 2.6558233,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 3.1309121,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 0.8798655,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.5007235,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.2426463,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 0.7319915,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.4172638,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 0.731192,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.4064354,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 10.9980932,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 3.0532941,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 11.2288805,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 7.8610367,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 8.469095,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 7.6077342,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 11.2213429,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 3.443925,
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
          "id": "e054896c7e11170a370add95122459a745df32d2",
          "message": "refactor: purification (#35)\n\n* refactor(install): run the installer in PowerShell 7 and share bin helpers\n\n* refactor(install): trust the generated catalog and share one safe path check\n\n* feat(install): one-line install for macOS and Linux that sets up PowerShell 7\n\n* refactor(bin): move shared helpers into bin/lib\n\n* refactor(install): pass the config folder only to the child process\n\n* refactor(bin): one launcher owner\n\n* refactor(install): one path comparison and link walk\n\n* refactor(bin): share PATH, channel and Foundry checks\n\n* refactor(tests): smaller integration engine and workflow checks\n\n* feat(install): uninstall and purge from a footprint index\n\n* feat(setup): add legion to the shell profile PATH on macOS and Linux\n\n* refactor(tests): one installer test harness\n\n* fix(install): remove the owner command when its last target is uninstalled\n\n* fix(setup): make the shell profile PATH pass on macOS and Linux\n\n* feat(bin): one limits command for every tool\n\n* fix(tests): keep system tools reachable in the footprint lifecycle test\n\n* fix(install): record only what legion adds and guard the footprint index\n\n* refactor(install): PowerShell 7.4 baseline and installer cleanup\n\n* refactor(install): a JSON-free POSIX bootstrap and build-time tool checks\n\n* refactor(bin): finish the shared helpers and fix limits\n\n* fix(tests): tests run only under the guard, so they never reach the real home\n\n* fix(limits): match the Codex session through linked temp folders\n\n* fix(tests): put every test home behind a link so path bugs show on every system\n\n* fix(tests): expect case-insensitive paths where the file system is\n\n* docs(overseer): three rules at the top of the checklist\n\n* docs(overseer): one rule per bullet\n\n* refactor(install): one set of PATH helpers and no dead installer code\n\n* wip: integration engine partial (codex-personal hit its limit)\n\n* refactor(tests): simpler integration engine and shared fixtures\n\n* fix(tests): check the one owner command directly in the integration suite\n\n* fix(install): consent before records, safe links and a locked purge\n\n* fix(tests): close the last guard holes and silent skips\n\n* docs: exact purge wording for the shell profile\n\n* docs: say line break, not blank line, in the purge wording",
          "timestamp": "2026-11-22T21:20:05+02:00",
          "tree_id": "72dc338bde4faf7605bca825f772f87498fb7f03",
          "url": "https://github.com/BlackGad/ps-legion-marketplace/commit/e054896c7e11170a370add95122459a745df32d2"
        },
        "date": 1795375553456,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 15.3212491,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 0.9762161,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 19.8128028,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.8770538,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 19.0945844,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.399189,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 25.3891977,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 9.7011225,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 20.6186257,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 3.9795772,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 6.7548165,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 1.3272029,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 0.8949068,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.5374745,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 2.308076,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.4013222,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 2.5964841,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.3505254,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 28.7718013,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 6.6881342,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 23.6887712,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 16.1891447,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 16.9608278,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 16.0127528,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 24.8403202,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 7.1860427,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 11.101634,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 0.6320962,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 6.2390095,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 0.7963443,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 4.8224301,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 0.8732785,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 11.4843924,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 7.1451788,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 20.3034877,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 3.2027157,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 4.2827864,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 1.2032823,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.5904087,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.523795,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 2.0465887,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 1.6391618,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 2.4052514,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 1.9274242,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 25.1176983,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 8.4905164,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 26.9385491,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 16.1997352,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 20.1931419,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 18.0584074,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 26.8662007,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 7.1963761,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 13.7637809,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.4283062,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 4.5028256,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.42854,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 3.7062531,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.5336097,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 9.1798443,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 4.5087819,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 9.9820887,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 2.4315803,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 3.0649622,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 0.801294,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.4942025,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.2412147,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 0.7236927,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.4168661,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 0.7290829,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.4044376,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 12.3385975,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 3.1022253,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 10.9983762,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 7.665318,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 8.1854134,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 7.6112724,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 11.1989123,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 3.3779702,
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
          "id": "cacc066c17266b97573beea48c81c3c49966cdce",
          "message": "chore(main): release 0.12.0 (#36)\n\nCo-authored-by: github-actions[bot] <41898282+github-actions[bot]@users.noreply.github.com>",
          "timestamp": "2026-11-22T21:24:44+02:00",
          "tree_id": "7b0e3dded37d04b2f6eed03e2703f4940dd2d0b1",
          "url": "https://github.com/BlackGad/ps-legion-marketplace/commit/cacc066c17266b97573beea48c81c3c49966cdce"
        },
        "date": 1795375859464,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 12.5741331,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 0.7732829,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 20.6618869,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.6936455,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 16.10032,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.2851442,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 30.2404247,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 7.5016919,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 15.9562422,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 3.1528864,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 5.7611412,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 1.1283296,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 0.7477943,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.4605223,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 6.280635,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.5004309,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 2.5499897,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.1061862,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 21.1482929,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 5.3926591,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 18.635102,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 12.3746898,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 13.1719238,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 12.5565166,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 18.7079762,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 5.3217247,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 11.7760258,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 0.9139933,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 7.1733816,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 0.9173485,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 6.5166481,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 1.262306,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 14.9971194,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 8.5848626,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 18.1339192,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 3.2793837,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 4.3602428,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 1.0348932,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.6582998,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.3754271,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 1.6392303,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 1.1435705,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 2.0231766,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 1.1073745,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 19.8103137,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 5.2595794,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 18.7436534,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 16.2954976,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 14.2701125,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 19.5890076,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 23.4296457,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 6.0987105,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 8.3373165,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.4876974,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 4.9447914,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.5341144,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 3.7615993,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.6497813,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 8.9959788,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 5.1209746,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 11.4947788,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 2.7159906,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 3.3325543,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 0.8296211,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.625581,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.3099198,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 0.9190457,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.5242115,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 0.9416597,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.5211029,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 14.2091783,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 3.4989662,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 12.2999669,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 8.6438025,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 9.1659621,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 8.604334,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 12.215237,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 3.7016242,
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
          "id": "3b5201524e1a52bd624fedb423917719925471a2",
          "message": "feat(telegram): give each overseer its own bot (#38)\n\n* feat(telegram): give each overseer its own bot folder\n\n* docs(telegram): say how to start the bot after configure",
          "timestamp": "2026-11-22T23:44:03+02:00",
          "tree_id": "cc65b31b004ac3eca034bb87ec6365620f82a729",
          "url": "https://github.com/BlackGad/ps-legion-marketplace/commit/3b5201524e1a52bd624fedb423917719925471a2"
        },
        "date": 1795384184532,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 14.6634019,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 1.115198,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 20.059464,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.9523816,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 19.5394232,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.418999,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 25.2850221,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 10.1650736,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 23.1215885,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 4.5696371,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 7.2250329,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 1.4878738,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 1.0513105,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.6106712,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 2.5311284,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.4806515,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 2.6409008,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.3665084,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 28.0832952,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 6.6964463,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 24.2835066,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 16.7063297,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 17.4487619,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 16.4097865,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 24.0922999,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 6.88027,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 13.0327683,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 0.8422163,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 6.7591277,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 0.8512005,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 5.4000685,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 1.0308692,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 12.2181988,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 7.1951681,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 14.7696385,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 2.4362394,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 3.8876116,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 0.7997571,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.5267033,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.2978921,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 1.4971264,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 1.0623537,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 1.6715337,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 0.80062,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 17.6236396,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 4.7454902,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 13.6632497,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 10.2570026,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 9.795261,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 9.4517592,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 14.7121752,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 3.8678257,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 12.2417758,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.5016841,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 4.5611471,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.4347327,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 3.4758771,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.5539676,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 9.4340664,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 4.6127894,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 10.0844347,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 2.4766661,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 2.9847181,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 0.819215,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.5025503,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.2461763,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 0.7434944,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.4341012,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 0.7591013,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.4167961,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 12.5195105,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 3.2131384,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 11.0517308,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 7.8996064,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 8.3395974,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 7.8138494,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 11.1901686,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 3.4959963,
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
          "id": "c32bb95374a12ab34360471f403b572ecc215845",
          "message": "feat(python): add uv project and CLI bridge (#37)\n\n* feat(python): add uv project and CLI bridge\n\n* ci: check Python across three platforms",
          "timestamp": "2026-11-22T23:45:24+02:00",
          "tree_id": "6f8a2d018b5df7253b2f858f7eff6aad43194a3e",
          "url": "https://github.com/BlackGad/ps-legion-marketplace/commit/c32bb95374a12ab34360471f403b572ecc215845"
        },
        "date": 1795384489041,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 14.0487273,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 0.7803249,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 18.4369057,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.7293626,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 22.1560226,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.0230474,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 25.0146166,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 7.4719057,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 16.2036885,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 3.3694577,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 5.8550422,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 1.1336055,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 0.8408355,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.5239755,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 2.1017026,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.2457773,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 2.1885531,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.1223404,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 22.3024827,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 5.3475665,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 19.6487275,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 13.253627,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 13.9798316,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 13.331414,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 20.8298673,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 6.2308776,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 12.9963666,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 1.2182076,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 8.7297282,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 1.3209399,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 5.0741754,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 0.8993902,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 12.5597955,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 7.908451,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 14.521195,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 3.9253345,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 4.9971043,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 0.9541545,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.672388,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.3693178,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 1.7656061,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 1.3034867,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 1.7387843,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 1.1857062,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 20.4540608,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 4.8769872,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 18.2771351,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 12.0447948,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 15.623979,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 17.1351826,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 25.7362404,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 6.441818,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 11.8436354,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.462928,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 4.7561613,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.4558927,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 3.591826,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.569281,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 9.9166582,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 4.6378602,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 10.1843959,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 2.5306889,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 2.9799815,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 0.8082663,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.5103277,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.254535,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 0.7566744,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.4355011,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 0.7386137,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.420936,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 12.9982074,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 3.2733633,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 11.1086376,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 7.826073,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 8.4610556,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 7.93463,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 11.5075257,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 3.5579714,
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
          "id": "65f2e4d9bc8b07cc93058275b6241426bec2984c",
          "message": "feat(inbox): add repository overseer messages (#40)\n\n* feat(inbox): add repository overseer messages\n\n* refactor(inbox): run the nudge synchronously",
          "timestamp": "2026-11-23T09:47:21+02:00",
          "tree_id": "aa49565955a7685a6f4e09ae07b1e9f97e1c799e",
          "url": "https://github.com/BlackGad/ps-legion-marketplace/commit/65f2e4d9bc8b07cc93058275b6241426bec2984c"
        },
        "date": 1795420391058,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 14.3547468,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 0.9479796,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 19.4653821,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.8185124,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 19.1791296,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.2197001,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 26.1392805,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 9.0323573,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 21.171815,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 4.9376346,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 7.2187296,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 1.335865,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 0.9013186,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.5571897,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 2.5251971,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.4439498,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 2.7122564,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.4696545,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 27.996243,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 8.4097359,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 27.1740905,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 18.045448,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 16.6716449,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 15.6015627,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 24.3068952,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 6.8566709,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 14.2900855,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 1.5995895,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 11.1720263,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 1.2700414,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 5.7989945,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 1.1304185,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 12.0469383,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 7.1278483,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 12.2004693,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 2.6638381,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 4.0040537,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 0.9083751,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.844292,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.4411504,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 2.8499511,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 0.8231287,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 1.7668204,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 0.8623215,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 19.5058248,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 4.159996,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 15.2508125,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 10.0936381,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 11.1689352,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 10.6795614,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 17.0869189,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 5.4548811,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 13.1385798,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.4842695,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 4.635766,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.4449872,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 3.7371688,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.5414591,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 8.734451,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 4.4923684,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 10.0422187,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 2.4730874,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 3.0749788,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 0.79972,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.4960376,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.2403937,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 0.723558,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.4176047,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 0.7222362,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.4203709,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 12.6999447,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 3.1949172,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 11.3346374,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 7.6582074,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 8.0641152,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 7.6107131,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 11.12337,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 3.3335151,
            "unit": "s"
          }
        ]
      }
    ]
  }
}