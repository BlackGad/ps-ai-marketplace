window.BENCHMARK_DATA = {
  "lastUpdate": 1795515736538,
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
          "id": "cf439d24fda9e2be69ad75276fb27a854282c506",
          "message": "feat(telegram): run Telegram on Codex through a bridge and send script (#41)\n\n* feat(inbox): add repository overseer messages\n\n* refactor(inbox): run the nudge synchronously\n\n* Revert \"refactor(inbox): run the nudge synchronously\"\n\nThis reverts commit 93ea5a9de71d3fcc40315f8bc1e1edc7d9b89436.\n\n* feat(telegram): run Telegram on Codex through a bridge and send script\n\n* style(telegram): use Optional for optional types\n\n* fix(inbox): write UTF-8, show the sender path, skip bad files and mark the body\n\n* fix(telegram): hide token in HTTP errors, claim bridge.pid exclusively, honour dmPolicy, drop docstrings\n\n* fix(inbox): decode child output as UTF-8 and make the documented commands show the whole output\n\n* fix(telegram): remove bridge.pid only when its process is gone; correct connect and install docs\n\n* fix: drop merge conflict markers",
          "timestamp": "2026-11-23T10:01:23+02:00",
          "tree_id": "5dd1ccb21d4e06b09f12b7294e3d2f6cd54a7de3",
          "url": "https://github.com/BlackGad/ps-legion-marketplace/commit/cf439d24fda9e2be69ad75276fb27a854282c506"
        },
        "date": 1795421212531,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 13.3916748,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 0.8889077,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 19.0069208,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.8168551,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 17.4024681,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.1930799,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 23.4507999,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 8.9954559,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 20.3902072,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 3.842929,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 6.4194044,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 1.2743966,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 0.8487652,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.5136601,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 2.2054334,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.3544422,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 2.4138423,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.2812055,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 26.3937323,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 6.2558642,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 22.444145,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 15.107245,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 16.0630828,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 15.09712,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 23.2037026,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 6.5437608,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 13.0714282,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 1.7071073,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 10.6639085,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 1.6316407,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 6.410064,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 1.247465,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 16.6039356,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 9.5240828,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 17.8350267,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 2.6143356,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 4.0933618,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 1.3583346,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.875191,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.443752,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 2.2454788,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 1.5397532,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 2.6602408,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 1.7167275,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 29.750723,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 5.5058071,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 19.1368012,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 15.1468842,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 19.9771401,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 17.5663667,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 24.1115816,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 9.4778302,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 7.757808,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.9957007,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 6.5348076,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.6380072,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 4.5129484,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.7537067,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 10.6896537,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 6.1100902,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 13.7292013,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 3.2069977,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 4.1226246,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 1.0532549,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.7254985,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.3450111,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 1.0304687,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.6026031,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 1.0791397,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.5935159,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 16.8034506,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 4.2437042,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 15.0130318,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 10.4219793,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 11.0862145,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 10.4469328,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 14.7184144,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 4.4209359,
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
          "id": "664ffbf89ec5cad67d74b14d42d4d35f210708e3",
          "message": "fix(ci): pass the token to the report timing step (#42)",
          "timestamp": "2026-11-23T10:15:59+02:00",
          "tree_id": "e2441bb84d787222216dc517eab52131553895fc",
          "url": "https://github.com/BlackGad/ps-legion-marketplace/commit/664ffbf89ec5cad67d74b14d42d4d35f210708e3"
        },
        "date": 1795422118823,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 16.0842956,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 1.0647025,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 20.8232315,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.9383772,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 18.1689557,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.3682012,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 24.5558857,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 9.8355633,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 20.2919611,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 4.1942296,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 7.2491175,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 1.5403873,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 1.055387,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.62607,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 2.5099313,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.464642,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 2.871732,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.6053441,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 29.2403866,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 7.2499673,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 25.1544575,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 16.524301,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 17.5585771,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 16.5732452,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 24.6887312,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 7.0188695,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 12.9430413,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 0.9691201,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 8.6863964,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 1.4887313,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 5.5096038,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 1.3459565,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 15.5541824,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 7.6717672,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 17.948093,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 3.3083237,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 3.9469792,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 0.9625695,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.7245967,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.4028905,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 1.8029376,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 1.4975693,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 3.2879426,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 1.4479304,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 20.6256524,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 4.6005345,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 21.4878025,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 18.5085305,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 16.2188234,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 13.0530239,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 22.1722986,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 6.2854992,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 14.9870261,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.4430357,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 4.5574982,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.4318175,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 3.5942275,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.5634934,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 10.5371482,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 4.572335,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 10.3944556,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 2.5661026,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 3.249822,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 0.8195605,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.507213,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.247362,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 0.7572423,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.4272045,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 0.750444,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.4271596,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 12.8397267,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 3.2421989,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 11.4288804,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 7.5981363,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 8.1044969,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 7.653322,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 11.1246747,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 3.421805,
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
          "id": "cfd28b9893be0be72832303bea124e5465bf8db5",
          "message": "chore(main): release 0.13.0 (#39)\n\nCo-authored-by: github-actions[bot] <41898282+github-actions[bot]@users.noreply.github.com>",
          "timestamp": "2026-11-23T10:24:01+02:00",
          "tree_id": "ab26812f244b8b0f56a2da4a698d5c507e1ae8fd",
          "url": "https://github.com/BlackGad/ps-legion-marketplace/commit/cfd28b9893be0be72832303bea124e5465bf8db5"
        },
        "date": 1795422505892,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 11.6881369,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 0.6820186,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 15.4979585,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.6024511,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 17.7912359,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 0.9932535,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 18.4005612,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 6.7318785,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 14.3199773,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 2.9063925,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 4.764582,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 0.9512914,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 0.6545473,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.4045651,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 1.6736721,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 0.9452792,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 1.7575454,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 0.9158856,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 20.2120723,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 4.773139,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 17.4036766,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 12.1324327,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 12.2585404,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 11.6088792,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 17.8337312,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 5.2586232,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 12.8820026,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 0.7788674,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 8.3844794,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 1.2706957,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 6.9667176,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 1.1344933,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 14.6024314,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 8.0739275,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 19.7546285,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 3.359217,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 5.5859232,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 1.1768461,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.7556274,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.4316025,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 1.9977832,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 1.627054,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 2.8952397,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 1.1463676,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 21.3888094,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 4.6383966,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 17.1860428,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 13.53843,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 13.5894632,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 14.3819712,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 19.6021339,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 6.1957726,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 7.6933129,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 1.093624,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 7.0082391,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.7540755,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 4.8101882,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.8552889,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 12.393991,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 6.5802954,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 14.7736583,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 3.4810697,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 5.0742553,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 1.1110887,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.7580165,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.39807,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 1.1682838,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.6649237,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 1.2238439,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.6631263,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 17.0962697,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 4.506498,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 15.7109497,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 11.2021103,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 12.0413053,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 11.2838036,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 15.5753259,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 4.8357248,
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
          "id": "bff29a44b9f9f7f56b677c1f0517187646a8e40d",
          "message": "fix(overseer): keep a Codex overseer on Telegram reachable (#43)\n\n* fix(overseer): keep the lease while waiting\n\n* docs(telegram): treat the Codex bridge as the channel\n\n* fix(python): one environment per plugin copy\n\n* fix(python): resolve the plugin root before hashing",
          "timestamp": "2026-11-23T11:41:51+02:00",
          "tree_id": "d824c0b5ba67ff9cda2d98cd8bd621a270c7bc46",
          "url": "https://github.com/BlackGad/ps-legion-marketplace/commit/bff29a44b9f9f7f56b677c1f0517187646a8e40d"
        },
        "date": 1795427238869,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 17.2440713,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 1.1811061,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 19.3983181,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.9281196,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 17.9535067,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.2931039,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 24.8197309,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 9.4705114,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 20.8283275,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 4.2898258,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 6.7225717,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 1.3994351,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 0.9364516,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.5754075,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 2.3242562,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.3828142,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 2.6168388,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.3504351,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 26.3736826,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 6.4880651,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 23.3228283,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 15.9716125,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 16.7890224,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 16.0239658,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 23.5924567,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 6.8247477,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 8.7324165,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 0.7379229,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 5.5680167,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 0.8170443,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 4.6006099,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 1.0326562,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 12.2142822,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 6.072304,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 12.8216926,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 2.6601989,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 3.6165238,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 0.9056839,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.6458213,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.3649719,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 1.9651988,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 1.1995002,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 1.9040348,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 0.7156136,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 15.4256078,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 6.000606,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 13.7932725,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 10.3245927,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 12.5582832,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 17.1595751,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 23.8294872,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 5.5692502,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 10.9060169,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.5607035,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 5.8599201,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.5662563,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 4.6102524,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.7233731,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 10.5435203,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 5.9583102,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 13.1025023,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 3.0658427,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 3.9698985,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 0.9942587,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.6378755,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.3228647,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 0.9721845,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.5598791,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 1.8805446,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.661682,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 16.125385,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 4.0727088,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 14.5650106,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 10.173459,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 10.8303358,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 10.3383999,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 15.6182866,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 4.3812,
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
          "id": "99b53d19b1c90f03f372e8e464758330c5925021",
          "message": "chore(main): release 0.13.1 (#44)\n\nCo-authored-by: github-actions[bot] <41898282+github-actions[bot]@users.noreply.github.com>",
          "timestamp": "2026-11-23T11:54:17+02:00",
          "tree_id": "ea34be38c9b269845695a49a5dff50d39213f3c1",
          "url": "https://github.com/BlackGad/ps-legion-marketplace/commit/99b53d19b1c90f03f372e8e464758330c5925021"
        },
        "date": 1795428005228,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 14.527099,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 1.0602378,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 19.8749154,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.9254815,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 28.2029846,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.9269805,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 23.8358671,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 9.9929927,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 21.0757291,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 4.2245092,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 6.7342807,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 1.3717643,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 0.9925089,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.6054879,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 2.324691,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.3971513,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 2.7013639,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.3503384,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 27.6829975,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 6.3996761,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 23.5182268,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 16.1882782,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 16.6875006,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 16.2370953,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 25.2462009,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 7.3674158,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 6.9966905,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 0.5189218,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 4.6163051,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 0.5778464,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 3.4984866,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 0.6894442,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 9.5730406,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 5.0805732,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 10.7037865,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 2.1532693,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 3.038323,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 0.6568474,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.4391132,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.255942,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 1.3315004,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 0.7382994,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 1.5685997,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 0.9584764,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 15.6907327,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 3.7284247,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 12.2206439,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 9.9399026,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 8.6897623,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 8.4567248,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 12.5870327,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 3.7728657,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 10.0947652,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.8570629,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 4.623812,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.4261079,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 3.5324309,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.5460049,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 8.7582608,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 4.485088,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 9.6109643,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 2.4190215,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 2.814864,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 0.7937922,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.5030608,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.2345952,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 0.7050724,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.3967715,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 0.7034465,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.4109877,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 12.0081056,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 3.1242105,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 10.7875849,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 7.7476787,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 8.1039825,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 7.5953936,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 10.9734859,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 3.5111961,
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
          "id": "65f8951383063408bb5ca4575b12631acb8b47e3",
          "message": "feat(python)!: rename the CLI to legion and parse arguments with Click (#45)",
          "timestamp": "2026-11-23T13:13:03+02:00",
          "tree_id": "356cd404bce4533cbadf4ca2cce101b985b4cdf4",
          "url": "https://github.com/BlackGad/ps-legion-marketplace/commit/65f8951383063408bb5ca4575b12631acb8b47e3"
        },
        "date": 1795432736491,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 14.4892177,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 1.048718,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 19.1632629,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.9236429,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 19.2049214,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.3854002,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 25.4479249,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 11.0805867,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 24.5806363,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 4.2812455,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 7.0448356,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 1.5582733,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 1.1019695,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.6794973,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 2.72656,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.6684642,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 3.146729,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.4506686,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 27.6325763,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 6.6158235,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 24.20345,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 16.869074,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 17.9491794,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 16.7126889,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 25.0692812,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 7.0549774,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 14.6490134,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 1.9558262,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 13.8423779,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 1.3087804,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 6.8828957,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 1.4629886,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 16.0170002,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 11.6284093,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 20.8153977,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 4.9275549,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 5.1011967,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 1.2432696,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 1.0088352,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.4380298,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 2.2940207,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 1.1614895,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 1.9024877,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 1.1024797,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 26.3633057,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 5.5050639,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 18.9879837,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 14.044851,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 15.620569,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 14.421001,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 21.267756,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 6.5534156,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 13.5891138,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.4201503,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 4.4739604,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.4185997,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 3.3390938,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.5247274,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 8.9394146,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 4.3921454,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 9.7052108,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 2.4128581,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 2.781322,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 0.7685079,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.4795107,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.2407331,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 0.7248875,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.4047955,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 0.7037698,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.4044635,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 11.6815559,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 3.0008913,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 10.5269227,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 7.4649193,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 7.8156507,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 7.2374749,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 10.481217,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 3.235367,
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
          "id": "ad39f520b5978bbd37789ca03481c30c0ed7a219",
          "message": "feat: run the legion command from the Python app in the legion folder (#47)\n\n* feat(python)!: rename the CLI to legion and parse arguments with Click\n\n* feat: run the legion command from the Python app in the legion folder\n\n* fix: pass uv's real exit code from the Windows legion command\n\n* fix(test): retry a failed winget install with the zip method in integration\n\n* fix: use and remove only recorded, ready legion app versions, and prune after publishing\n\n* fix(test): make the default fake uv reject calls a test did not opt into\n\n* fix(python): allow ruff S603 across legion product code\n\n* fix: make app lifecycle tests portable\n\nRemove hidden ready markers with -Force on POSIX and exercise purge through the public uninstall flow so app records are removed first.",
          "timestamp": "2026-11-23T15:22:15+02:00",
          "tree_id": "bc49b7c7ea6640321cd07d0b7426351a3638382e",
          "url": "https://github.com/BlackGad/ps-legion-marketplace/commit/ad39f520b5978bbd37789ca03481c30c0ed7a219"
        },
        "date": 1795440428542,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 13.1481863,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 0.8405779,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 17.307444,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.7479391,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 14.7023042,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.0293755,
            "unit": "s"
          },
          {
            "name": "windows / install-uv",
            "value": 6.2688803,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-uv (repeat)",
            "value": 0.6845614,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 22.9758148,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 8.1141197,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 18.6076823,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 3.5516325,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 5.5544461,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 1.16928,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 0.7716222,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.474947,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 1.8680798,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.066846,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 1.9850339,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.0430416,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 21.2942655,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 5.1034415,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 20.5922926,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 13.8331045,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 14.5743948,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 15.2477794,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 20.6812846,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 5.8829928,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 12.9685827,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 1.7760791,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 8.2279107,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 1.3315699,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 6.9899341,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 1.331102,
            "unit": "s"
          },
          {
            "name": "macos / install-uv",
            "value": 1.3716826,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-uv (repeat)",
            "value": 0.6659777,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 15.0891123,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 6.7845704,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 18.330658,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 5.3366277,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 6.1012017,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 1.375405,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.835926,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.5143044,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 2.1192722,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 1.3020617,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 2.4432004,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 1.3829735,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 22.9472767,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 5.6187816,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 21.9483099,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 16.5864152,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 18.5131207,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 16.3955071,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 18.714488,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 5.135936,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 12.8948212,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.4673891,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 4.5440636,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.428491,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 3.4765809,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.5478497,
            "unit": "s"
          },
          {
            "name": "linux / install-uv",
            "value": 0.941431,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-uv (repeat)",
            "value": 0.3742927,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 10.9800389,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 4.9571829,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 11.6264358,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 2.9107529,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 3.504528,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 0.9281531,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.4926682,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.2381261,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 0.7137869,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.5367831,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 1.3092047,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.4142595,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 12.2326116,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 3.0353122,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 12.1867724,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 8.3773401,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 8.8756991,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 8.4707902,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 11.1949835,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 3.315949,
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
          "id": "51583c5fad83705dc7a1a31e7887b4fbc0f2f64f",
          "message": "feat(python): validate settings in Python with typed pydantic models (#48)\n\n* feat(python)!: rename the CLI to legion and parse arguments with Click\n\n* feat: run the legion command from the Python app in the legion folder\n\n* fix: pass uv's real exit code from the Windows legion command\n\n* fix(test): retry a failed winget install with the zip method in integration\n\n* fix: use and remove only recorded, ready legion app versions, and prune after publishing\n\n* fix(test): make the default fake uv reject calls a test did not opt into\n\n* fix(python): allow ruff S603 across legion product code\n\n* feat(python): validate settings and project files in Python\n\n* fix: make app lifecycle tests portable\n\nRemove hidden ready markers with -Force on POSIX and exercise purge through the public uninstall flow so app records are removed first.\n\n* fix: harden app sync, the Windows owner command and the bridge home\n\n- The Windows legion.cmd finds the app, its environment and the home from\n  its own folder (%~dp0) and stays ASCII, so a non-ASCII home works on any\n  console code page.\n- Every sync checks the version and environment folders for links, and\n  rechecks the whole version before it is marked ready.\n- Python calls from PowerShell, such as the overseer's Telegram bridge,\n  pass a non-default home as --home.\n- A refresh waits up to 60 s for a running sync, then compares versions.\n- A recorded version without the ready marker is never run, but prune and\n  uninstall remove it.\n- One uv lookup and one uv-missing message; the marker name comes from\n  Get-LegionAppMarker; one link check of the app folder; a named flag in\n  purge.\n\n* fix(validate): reject duplicate keys and read UTF-16 files\n\n- A key written twice is a framed error, as with the old Test-Json check.\n- A file with a UTF-8 or UTF-16 (LE/BE) byte-order mark is decoded.\n- Recorded cases carry their file path; duplicate-key and UTF-16 cases are\n  added, missing-file keeps only its framed line, bom-crlf is dropped.\n- Tool schema cases are one edit (JSON pointer path and value) of a real\n  descriptor instead of seven full copies; the valid copy is dropped.\n- Tests that repeated the recorded cases are removed.\n\n* fix(python): normalise the selected home and fence child interpreters\n\n- --home <home>/.legion/bin/../.. (from the Windows command) becomes <home>.\n- One PLUGIN_ROOT in legion._plugin replaces four copies.\n- The pytest fence points PYTHONPYCACHEPREFIX into the sandbox and clears\n  PYTHONSTARTUP and PYTHONUSERBASE for child interpreters.\n- The lazy-import test also checks legion._validate and fastjsonschema.\n- The test runner maps a non-integer exit code to 1, as Python does.\n\n* docs(personalisation): validate settings through Invoke-LegionPython\n\n* refactor(python): typed pydantic models for every JSON shape",
          "timestamp": "2026-11-23T16:44:37+02:00",
          "tree_id": "f20534efda2ce538a62da2729b85a38ba765c8aa",
          "url": "https://github.com/BlackGad/ps-legion-marketplace/commit/51583c5fad83705dc7a1a31e7887b4fbc0f2f64f"
        },
        "date": 1795445475620,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 16.7189307,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 1.0667764,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 20.0509681,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 1.0443123,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 20.6363713,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.6016831,
            "unit": "s"
          },
          {
            "name": "windows / install-uv",
            "value": 8.2085143,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-uv (repeat)",
            "value": 1.0420658,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 31.9731563,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 10.9044884,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 25.8501214,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 5.6114141,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 8.2220439,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 1.5694768,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 0.9728237,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.587933,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 2.3468324,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.4196351,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 2.6101607,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.5396363,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 30.180114,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 6.8489047,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 28.190313,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 18.821579,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 21.2966965,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 19.9593094,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 26.3227691,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 7.421587,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 10.5198442,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 0.6050317,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 5.0268574,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 0.8769875,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 5.8936015,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 1.4870789,
            "unit": "s"
          },
          {
            "name": "macos / install-uv",
            "value": 2.0362188,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-uv (repeat)",
            "value": 0.8873165,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 22.2077033,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 9.4476421,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 17.6599668,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 2.738907,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 3.4936402,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 1.2282971,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.7150206,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.3862187,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 1.5111911,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 0.8293264,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 1.612101,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 0.9165018,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 26.1151768,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 4.7753258,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 21.5497115,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 14.1351042,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 13.1586985,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 15.918056,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 19.4186514,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 5.2581834,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 12.7008955,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.6640867,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 20.6664994,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.7189123,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 4.8530133,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.8703755,
            "unit": "s"
          },
          {
            "name": "linux / install-uv",
            "value": 1.3433386,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-uv (repeat)",
            "value": 0.6521835,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 14.7667614,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 7.5156464,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 17.1771765,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 4.0927491,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 4.7458065,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 1.312794,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.7779296,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.4131159,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 1.0138269,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.6683175,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 1.0214941,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.6543471,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 18.1791607,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 4.5558363,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 17.7928498,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 12.8255358,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 13.5971034,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 12.7151353,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 15.8085453,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 4.8523796,
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
          "id": "359fc097c671cb0cac51ad0a8b23dfd89ea59b61",
          "message": "chore(main): release 0.14.0 (#46)\n\nCo-authored-by: github-actions[bot] <41898282+github-actions[bot]@users.noreply.github.com>",
          "timestamp": "2026-11-23T16:47:24+02:00",
          "tree_id": "d224ce06e30f83d6005a05641722fba4f608efa6",
          "url": "https://github.com/BlackGad/ps-legion-marketplace/commit/359fc097c671cb0cac51ad0a8b23dfd89ea59b61"
        },
        "date": 1795445770595,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 12.1780751,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 0.7098082,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 21.7229536,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.5698373,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 13.7621762,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 0.7688164,
            "unit": "s"
          },
          {
            "name": "windows / install-uv",
            "value": 6.2907561,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-uv (repeat)",
            "value": 0.5393302,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 23.7387369,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 7.3388039,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 15.2589558,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 2.8106204,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 4.5296356,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 0.9098621,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 0.5980069,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.4016714,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 1.5124429,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 0.9194764,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 1.5575239,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 0.8526583,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 18.8884304,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 4.5259676,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 20.7862533,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 14.1106909,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 14.357291,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 13.2781073,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 18.6586017,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 4.8806734,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 15.0306329,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 1.0926199,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 9.7331999,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 1.4118087,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 9.2450656,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 1.7158664,
            "unit": "s"
          },
          {
            "name": "macos / install-uv",
            "value": 2.4538057,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-uv (repeat)",
            "value": 0.9129588,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 20.3871455,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 7.6071186,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 23.8503277,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 5.2270888,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 5.8368254,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 1.4147261,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.8767985,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.362783,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 1.6661762,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 1.0482397,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 1.7250984,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 0.8440475,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 23.3747553,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 5.033736,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 21.3295983,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 12.8292057,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 17.1588737,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 14.3077217,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 18.4406006,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 4.0584171,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 8.6120897,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 1.1179166,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 6.9825406,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.6980241,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 5.1136424,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.9370081,
            "unit": "s"
          },
          {
            "name": "linux / install-uv",
            "value": 1.490041,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-uv (repeat)",
            "value": 0.6428083,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 12.9920341,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 7.5835701,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 17.3285374,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 4.0531177,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 4.9930421,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 1.4318646,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.768724,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.400793,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 1.0085367,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.6478512,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 1.0261259,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.6305486,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 17.4704285,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 4.554212,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 17.456093,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 12.6273226,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 13.8350522,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 13.2477679,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 15.7789743,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 4.8098534,
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
          "id": "ba7af007ca8cd66c41f69b4d705a8abad2571be3",
          "message": "fix(tests): keep tests out of the real user PATH (#49)\n\n* fix(tests): keep tests out of the real user PATH\n\n* fix(tests): keep the real user PATH in the integration suite",
          "timestamp": "2026-11-23T18:37:16+02:00",
          "tree_id": "3794a5adf7cff416e55ca5f6012a42232cf525b1",
          "url": "https://github.com/BlackGad/ps-legion-marketplace/commit/ba7af007ca8cd66c41f69b4d705a8abad2571be3"
        },
        "date": 1795452239151,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 17.3077592,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 1.1026739,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 19.9468119,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.9664043,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 29.2779855,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.4954572,
            "unit": "s"
          },
          {
            "name": "windows / install-uv",
            "value": 7.743853,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-uv (repeat)",
            "value": 0.8933034,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 37.1412297,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 10.6098481,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 29.28303,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 5.2394196,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 7.5028871,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 1.6015005,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 1.0059034,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.6192629,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 2.354567,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.3910157,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 2.4585878,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.366661,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 27.0475316,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 6.7245269,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 26.7375393,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 18.6620053,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 21.9686625,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 18.5013766,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 24.3659193,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 6.7830114,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 20.8003847,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 1.9701415,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 12.9162844,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 2.2346547,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 9.5276689,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 1.9308113,
            "unit": "s"
          },
          {
            "name": "macos / install-uv",
            "value": 2.7318753,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-uv (repeat)",
            "value": 1.2213348,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 27.1758742,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 14.5926564,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 25.3980362,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 5.5723402,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 6.1915099,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 1.5246968,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.8891289,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.6266085,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 2.2489507,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 1.2409458,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 2.14399,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 1.5885009,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 31.6630163,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 8.2482484,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 28.6594427,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 21.421207,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 20.4409746,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 13.8728018,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 17.5192623,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 5.6663906,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 13.3659235,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.4884461,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 4.729316,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.4450528,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 3.8205192,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.5658167,
            "unit": "s"
          },
          {
            "name": "linux / install-uv",
            "value": 1.3577015,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-uv (repeat)",
            "value": 0.4486239,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 11.9195148,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 5.2432512,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 12.2003427,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 3.0524244,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 3.6071751,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 1.0104665,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.5030132,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.2544571,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 0.6564891,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.4006059,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 0.637462,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.3980599,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 13.0145008,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 3.2965085,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 12.9071635,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 9.0106137,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 9.3576619,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 8.7983021,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 11.512105,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 3.401423,
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
          "id": "bc2cc84b698bb1511b4e0202e3812643ca904381",
          "message": "feat(python): take and release the overseer lease in Python (#51)\n\n* feat(python): find the owner process and run commands with a timeout\n\n* feat(python): read, take and release the overseer lease\n\n* feat(python): legion lease and an inbox nudge without PowerShell",
          "timestamp": "2026-11-23T19:46:02+02:00",
          "tree_id": "c4cefe02e5bb5e61d555c437de4a745736d249ba",
          "url": "https://github.com/BlackGad/ps-legion-marketplace/commit/bc2cc84b698bb1511b4e0202e3812643ca904381"
        },
        "date": 1795456349807,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 14.7701254,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 1.1026847,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 18.3853363,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.9336378,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 19.5655542,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.4193768,
            "unit": "s"
          },
          {
            "name": "windows / install-uv",
            "value": 7.8906158,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-uv (repeat)",
            "value": 0.9150755,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 28.1450206,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 10.9845205,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 26.2410605,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 5.1086458,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 8.0612457,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 1.8223065,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 1.101255,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.6903728,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 3.5420297,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.6408745,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 3.3335187,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.439455,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 28.6054321,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 6.6630709,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 27.2502568,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 18.5509355,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 19.3559538,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 18.602407,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 24.7445234,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 7.0991913,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 12.6228253,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 1.0428644,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 8.1061137,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 1.1415819,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 6.403121,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 1.1753655,
            "unit": "s"
          },
          {
            "name": "macos / install-uv",
            "value": 1.7056891,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-uv (repeat)",
            "value": 0.7252466,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 17.5570461,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 9.1926099,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 21.2954943,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 3.8433703,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 5.7255454,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 1.4164654,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.7790351,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.4792363,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 3.3416164,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 1.94514,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 4.9682882,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 1.5437728,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 25.2631907,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 5.5729779,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 22.0454601,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 16.5025964,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 15.3836347,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 14.9555894,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 17.8474216,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 5.13233,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 10.1405273,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 1.1764191,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 6.5441125,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.8034148,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 5.059295,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.8800614,
            "unit": "s"
          },
          {
            "name": "linux / install-uv",
            "value": 1.5976586,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-uv (repeat)",
            "value": 0.6647432,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 14.7465402,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 7.7967994,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 18.1320035,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 4.1282451,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 4.9551677,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 1.3186187,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.7727244,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.4049992,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 1.0046274,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.6759154,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 1.0497264,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.6644538,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 18.1673938,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 4.622823,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 18.3632063,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 12.9739953,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 13.9935755,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 13.2325185,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 16.245004,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 4.8884746,
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
          "id": "45041dccc56525bf25244b2e758f7fb5eabf9a48",
          "message": "feat(python): check for legion updates in Python (#52)\n\n* feat(python): check for legion updates in Python\n\n* refactor(python): parse legion update options with Click\n\n* style(python): comments instead of docstrings",
          "timestamp": "2026-11-23T20:48:39+02:00",
          "tree_id": "365a80c884ff79e94bb206ad8334443e970f5884",
          "url": "https://github.com/BlackGad/ps-legion-marketplace/commit/45041dccc56525bf25244b2e758f7fb5eabf9a48"
        },
        "date": 1795460125977,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 16.5978801,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 0.9660317,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 20.1125796,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.8785484,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 22.6766769,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.3616697,
            "unit": "s"
          },
          {
            "name": "windows / install-uv",
            "value": 7.7599725,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-uv (repeat)",
            "value": 0.8378967,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 54.7257258,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 10.3680782,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 26.0669494,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 4.7685484,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 7.9162966,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 1.5850644,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 1.0632388,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.6684215,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 3.451971,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.6200931,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 2.5985422,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.4470126,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 26.6838736,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 6.3661252,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 25.9701769,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 18.4547599,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 20.7775905,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 20.5207723,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 27.5723098,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 7.1578682,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 16.3800165,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 1.7231407,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 9.5326702,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 1.548314,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 6.734016,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 1.9184953,
            "unit": "s"
          },
          {
            "name": "macos / install-uv",
            "value": 2.3658915,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-uv (repeat)",
            "value": 1.1268134,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 22.073527,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 13.2997801,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 26.1605609,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 5.5799074,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 7.5481475,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 2.0174617,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 1.0213967,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.4321797,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 2.6060134,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 2.8431372,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 4.7935124,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 1.5737372,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 35.439097,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 8.8991603,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 27.8979882,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 20.434706,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 25.2515078,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 22.7075952,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 39.2314794,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 11.2181014,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 13.389431,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.4303659,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 4.5696652,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.4356016,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 3.5018733,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.5601692,
            "unit": "s"
          },
          {
            "name": "linux / install-uv",
            "value": 1.5398667,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-uv (repeat)",
            "value": 0.3965277,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 12.017609,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 5.0968216,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 11.547762,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 3.0088431,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 3.2499151,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 1.0313563,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.5372523,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.2730507,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 0.6187571,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.3919198,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 0.6382618,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.3783649,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 12.0616508,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 3.0796704,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 12.3030375,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 8.6119949,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 9.1067137,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 8.6724513,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 11.1088812,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 3.3853773,
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
          "id": "082253b8ac9799fe0efbdf60299c68fcaec8f2c3",
          "message": "feat(hooks): start sessions without PowerShell (#53)",
          "timestamp": "2026-11-23T21:27:13+02:00",
          "tree_id": "50e10f3a7bd8d7979f2bc78c17dc274b459d6f67",
          "url": "https://github.com/BlackGad/ps-legion-marketplace/commit/082253b8ac9799fe0efbdf60299c68fcaec8f2c3"
        },
        "date": 1795462393178,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 13.8698431,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 1.0293628,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 18.1603264,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.9156572,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 18.7958701,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.3536424,
            "unit": "s"
          },
          {
            "name": "windows / install-uv",
            "value": 7.6252123,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-uv (repeat)",
            "value": 0.8809585,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 27.2033555,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 10.7111092,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 23.7166772,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 4.9598779,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 7.5310415,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 1.7184435,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 1.0892377,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.6671459,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 2.5128768,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.5384316,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 2.5829365,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.3084103,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 29.363644,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 6.3423287,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 25.8023724,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 17.4878235,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 18.4800588,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 17.5486532,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 23.5595717,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 6.5934438,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 10.6619838,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 1.194675,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 6.7137479,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 1.0517368,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 5.6369342,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 1.2245071,
            "unit": "s"
          },
          {
            "name": "macos / install-uv",
            "value": 1.4708765,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-uv (repeat)",
            "value": 0.5303896,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 13.7496066,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 6.2614272,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 13.8248693,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 3.5737348,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 4.1950495,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 1.0265931,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.7073166,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.4462767,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 1.3905086,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 0.7778748,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 1.8560076,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 0.9843724,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 20.8514982,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 4.8896209,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 16.7680084,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 11.598935,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 15.1824141,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 13.083105,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 18.0897291,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 6.2222777,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 10.8523519,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.6319501,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 6.9000473,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.6027419,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 4.7596431,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.7521249,
            "unit": "s"
          },
          {
            "name": "linux / install-uv",
            "value": 1.3827694,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-uv (repeat)",
            "value": 0.548204,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 13.4763686,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 6.8787753,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 15.6197995,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 3.5743534,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 4.4120936,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 1.1399538,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.6763815,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.3432262,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 0.8970332,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.5545203,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 0.9494438,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.569151,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 16.8876826,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 4.2042509,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 16.7399586,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 11.6516592,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 12.1252654,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 11.5082011,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 15.1395904,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 4.5353442,
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
          "id": "9505b2a9a48f3c3fa17510847f1fbb96bc0b4dbc",
          "message": "fix(overseer): say when a channel's bot folder or token is missing (#54)",
          "timestamp": "2026-11-23T21:47:00+02:00",
          "tree_id": "f3886329f5e87e924bf88464649d3e85a5a74325",
          "url": "https://github.com/BlackGad/ps-legion-marketplace/commit/9505b2a9a48f3c3fa17510847f1fbb96bc0b4dbc"
        },
        "date": 1795463597987,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 14.7974653,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 1.1331071,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 18.6784938,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.9322376,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 18.8428955,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.3702814,
            "unit": "s"
          },
          {
            "name": "windows / install-uv",
            "value": 7.8622174,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-uv (repeat)",
            "value": 0.9139088,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 28.2652747,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 10.2389985,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 24.3435542,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 4.9571263,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 7.1912689,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 1.7328389,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 0.9826862,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.6031404,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 2.2460023,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.3480764,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 2.3637776,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.3165764,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 26.6227456,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 6.4306818,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 26.0247806,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 17.702212,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 18.5282987,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 17.5736124,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 23.8427982,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 6.7076933,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 9.010259,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 0.8696932,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 7.37199,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 0.8477707,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 5.5139562,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 1.2431429,
            "unit": "s"
          },
          {
            "name": "macos / install-uv",
            "value": 1.7971337,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-uv (repeat)",
            "value": 0.7368092,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 15.4352567,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 7.5871091,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 18.0635286,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 3.702868,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 4.7778491,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 1.0928225,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.5269839,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.3150626,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 1.5359841,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 0.953958,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 1.7419844,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 0.9967538,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 22.1706217,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 4.4307896,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 19.7959912,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 17.7219302,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 15.3386777,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 12.350968,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 18.8271861,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 6.1568469,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 14.1749529,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.4513854,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 4.7838361,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.4329051,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 3.5621134,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.6110905,
            "unit": "s"
          },
          {
            "name": "linux / install-uv",
            "value": 1.0050209,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-uv (repeat)",
            "value": 0.384782,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 10.2746413,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 5.1140161,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 11.5794122,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 3.0206913,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 3.2290106,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 0.9539479,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.5219248,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.2484471,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 0.6575725,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.4102058,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 0.6460656,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.4125351,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 12.2913974,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 3.1487533,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 12.4370996,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 9.026686,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 9.6213708,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 8.8347135,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 11.2674398,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 3.4288709,
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
          "id": "f00157b2c4e740dba57fc5a502bd8dfd3c1edd96",
          "message": "feat(python): show legion status in Python (#55)",
          "timestamp": "2026-11-23T21:57:37+02:00",
          "tree_id": "0c5afd846fc195be445459324a9f7dcebcf37b96",
          "url": "https://github.com/BlackGad/ps-legion-marketplace/commit/f00157b2c4e740dba57fc5a502bd8dfd3c1edd96"
        },
        "date": 1795464236908,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 14.6174406,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 1.0356347,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 19.607661,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.9208386,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 24.0229471,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.5680708,
            "unit": "s"
          },
          {
            "name": "windows / install-uv",
            "value": 10.8434794,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-uv (repeat)",
            "value": 0.9614398,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 30.1364056,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 10.3968136,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 23.4710904,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 4.9650916,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 8.0913965,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 1.7448574,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 1.074257,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.6813799,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 2.4980217,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.5782624,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 2.5369526,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.3553684,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 27.6478101,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 6.482082,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 26.1696476,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 18.8892969,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 22.0883137,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 21.4777035,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 24.1334913,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 6.7294834,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 10.6467222,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 1.0856619,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 6.6079744,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 1.1924735,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 6.0469985,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 1.3904406,
            "unit": "s"
          },
          {
            "name": "macos / install-uv",
            "value": 1.7085341,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-uv (repeat)",
            "value": 0.7324317,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 17.0077922,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 7.9123072,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 17.1883295,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 3.142885,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 4.7494122,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 1.2884737,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.6812723,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.4987008,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 2.3199661,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 1.1660465,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 2.1959026,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 1.5562215,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 32.3904333,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 4.8752345,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 21.1673341,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 18.082291,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 14.0834285,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 12.1932971,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 17.181488,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 4.3730992,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 12.8042982,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.4600358,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 4.5837228,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.4228694,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 3.4188626,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.5378503,
            "unit": "s"
          },
          {
            "name": "linux / install-uv",
            "value": 1.1811829,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-uv (repeat)",
            "value": 0.3776821,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 11.159472,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 5.0449914,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 11.1197226,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 3.0665435,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 3.2750739,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 0.9928455,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.5088633,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.2856372,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 0.8878158,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.4147585,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 0.9735681,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.4028211,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 11.9781091,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 3.069277,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 11.9685381,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 8.5498221,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 9.085667,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 8.794442,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 11.2934527,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 3.5953017,
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
          "id": "6b6be5558cb3471981e7626b844aa7d227412189",
          "message": "feat(python): read account limits in Python (#56)\n\n* feat(python): read account limits per tool\n\n* feat(python): read account limits in Python\n\n* test(python): compare resolved temp folders in the limits tests\n\n* test(python): resolve every path in the limits test comparisons",
          "timestamp": "2026-11-23T22:56:06+02:00",
          "tree_id": "daf3676d713e9f45c2ab156894758010867d6d9f",
          "url": "https://github.com/BlackGad/ps-legion-marketplace/commit/6b6be5558cb3471981e7626b844aa7d227412189"
        },
        "date": 1795467732845,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 14.8032437,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 1.1938824,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 18.5772609,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.9392065,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 21.3434551,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.4666914,
            "unit": "s"
          },
          {
            "name": "windows / install-uv",
            "value": 7.6474877,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-uv (repeat)",
            "value": 0.9087179,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 28.7591293,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 10.6288317,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 24.7545229,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 4.9690585,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 7.7738202,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 1.6188122,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 1.0039949,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.6162484,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 2.3702084,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.4638919,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 2.5813124,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.401503,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 31.7564384,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 6.5639057,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 26.2701031,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 18.065086,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 18.7794712,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 17.9929388,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 24.4768193,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 6.8678349,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 9.9794462,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 0.6742826,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 5.7004201,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 0.8645688,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 4.8808095,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 1.2415153,
            "unit": "s"
          },
          {
            "name": "macos / install-uv",
            "value": 1.4753637,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-uv (repeat)",
            "value": 0.6718995,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 13.8101042,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 6.032615,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 14.0930452,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 3.2395267,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 4.1370405,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 1.07846,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.6169303,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.4121665,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 1.6949012,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 1.0308333,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 1.4621095,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 0.8288059,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 17.6262301,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 3.9198037,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 15.8009746,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 11.775145,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 11.8802447,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 11.3767618,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 15.574957,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 4.2644132,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 9.2964386,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 1.07177,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 8.4974681,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.6883027,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 5.2442125,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.9396553,
            "unit": "s"
          },
          {
            "name": "linux / install-uv",
            "value": 1.4431993,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-uv (repeat)",
            "value": 0.6672069,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 12.5656789,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 7.2683642,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 15.766724,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 3.9024299,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 4.5390079,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 1.2924322,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.7414,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.3896577,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 0.9542567,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.6336925,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 1.0129106,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.6318046,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 16.9118366,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 4.3564612,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 17.115018,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 12.29712,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 13.0271872,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 12.279687,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 15.2686374,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 4.6825794,
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
          "id": "8858f83a25329686cd02c059c3fbc6ed9cdc4fbd",
          "message": "fix: close milestone 2 review findings on test fences and wording (#57)\n\n* fix: close milestone 2 review findings on test fences and wording\n\n* test(python): fix the update test that skipped the fake remote on Windows\n\nA delayed daemon worker can miss the deadline before reaching the fake\nopener. Stub downloads synchronously for cache and manifest tests, and\ncheck the real worker separately from manifest validation.",
          "timestamp": "2026-11-23T23:44:28+02:00",
          "tree_id": "087ebb9e9e546c94a8de51c6c882bedb0df4acc1",
          "url": "https://github.com/BlackGad/ps-legion-marketplace/commit/8858f83a25329686cd02c059c3fbc6ed9cdc4fbd"
        },
        "date": 1795470555571,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 12.5118327,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 0.7069492,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 14.9097938,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.6504045,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 15.6173504,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 0.8827236,
            "unit": "s"
          },
          {
            "name": "windows / install-uv",
            "value": 6.9609695,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-uv (repeat)",
            "value": 0.6703666,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 32.2651948,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 6.6418993,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 15.9204784,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 2.845347,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 4.6302404,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 0.9640754,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 0.6201927,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.3906798,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 1.5852594,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 0.892969,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 1.5716737,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 0.8597954,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 17.63759,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 4.5176736,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 17.396428,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 12.0463019,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 11.9380941,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 11.5393606,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 16.0115326,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 4.2516049,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 13.8292573,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 1.20275,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 9.1409442,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 1.4353761,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 7.3843263,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 1.629705,
            "unit": "s"
          },
          {
            "name": "macos / install-uv",
            "value": 1.7342277,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-uv (repeat)",
            "value": 0.7521387,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 16.361719,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 10.7715131,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 20.0936029,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 4.5441012,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 5.3471157,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 1.224829,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.5444526,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.3224842,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 2.1982515,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 1.2985217,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 1.9074317,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 1.4449681,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 24.1106189,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 6.115931,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 24.6844771,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 13.9443325,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 18.1954497,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 18.9867475,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 20.3199648,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 4.9691278,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 12.364476,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.568781,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 4.6483264,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.4343012,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 3.6617033,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.5468057,
            "unit": "s"
          },
          {
            "name": "linux / install-uv",
            "value": 1.5661045,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-uv (repeat)",
            "value": 0.372509,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 10.6942596,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 4.9300837,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 11.0181589,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 2.9574902,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 3.3096722,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 0.96629,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.5043551,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.2802208,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 0.8525291,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.4186122,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 0.9780628,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.3843423,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 12.0018029,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 3.026348,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 12.3478356,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 8.4899319,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 8.9438898,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 8.3961581,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 10.9121059,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 3.2441208,
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
          "id": "2945179cef347ed7f6026816f7edd5fb6565875b",
          "message": "fix(python): close milestone 2 review findings on process, lease and cache robustness (#58)\n\n* fix(python): close milestone 2 review findings on process, lease and cache robustness\n\n* test(python): time the stalled update check against the child's own start-up\n\n* fix(python): fail a lease change on a lock in use on Windows with the retry message",
          "timestamp": "2026-11-24T00:36:12+02:00",
          "tree_id": "87f9f7ecbdbad9567359922a6ba6a99ec9b8d7ab",
          "url": "https://github.com/BlackGad/ps-legion-marketplace/commit/2945179cef347ed7f6026816f7edd5fb6565875b"
        },
        "date": 1795473762821,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 15.5324952,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 1.182407,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 20.0409336,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.9859762,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 17.8814225,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.5554416,
            "unit": "s"
          },
          {
            "name": "windows / install-uv",
            "value": 7.8436662,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-uv (repeat)",
            "value": 0.9496551,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 29.8688941,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 11.6728044,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 24.9447113,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 5.2108019,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 7.6665515,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 1.730742,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 1.0825826,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.6586545,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 2.5020109,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.5034314,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 2.7128273,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.4857708,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 29.1126189,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 7.0426726,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 28.8790553,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 19.7453131,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 23.8505721,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 23.010037,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 26.4678131,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 7.374613,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 9.7997083,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 1.1107672,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 7.9138609,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 1.2240695,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 6.1621796,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 1.5950645,
            "unit": "s"
          },
          {
            "name": "macos / install-uv",
            "value": 2.1753691,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-uv (repeat)",
            "value": 0.8116184,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 16.8553948,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 8.3070315,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 17.7582765,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 3.4113135,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 4.0909997,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 1.0782691,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.680895,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.388993,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 1.5202612,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 1.1246303,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 2.8866523,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 1.2667082,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 20.4198113,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 4.5611448,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 18.0204202,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 12.7877351,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 15.0133108,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 13.8041562,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 16.7415281,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 5.3794741,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 13.028243,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.696913,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 6.4487412,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.7612357,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 4.9534077,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.960135,
            "unit": "s"
          },
          {
            "name": "linux / install-uv",
            "value": 1.4121198,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-uv (repeat)",
            "value": 0.6766442,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 13.8471393,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 7.7073201,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 17.5408234,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 4.2628928,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 5.0101821,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 1.3623123,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.8015426,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.4203955,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 1.0751063,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.6976404,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 1.0798403,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.6697643,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 18.5133424,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 4.8220824,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 18.8985248,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 13.4297752,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 14.0614747,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 13.3448185,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 16.7284128,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.171.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 5.0956432,
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
          "id": "7fae00b111053e98f810968f73be0d05203d99ed",
          "message": "refactor(python): typed limits readers and milestone 2 purification (#59)\n\n- Parse Claude rate_limit_event, Codex session rate_limits and the az token\n  answer with pydantic models; a line of the wrong shape is skipped like\n  unreadable JSON instead of raising a TypeError.\n- LimitRow, Ping, RunResult and TokenCheck are frozen pydantic models;\n  stdlib dataclasses stay on the hook import path only.\n- One home for the home layout (_home: settings_path, bin_folder,\n  wrapper_command, home_path); read_text, load_descriptors, call_bot and\n  PROCESS_QUERY_LIMITED_INFORMATION are public instead of imported private.\n- The hook reuses _plugin.PLUGIN_ROOT; status reads PluginManifest; the\n  update command is a constant.\n- legion lease release no longer accepts the ignored --tool and --account.\n- Drop the uncalled Get-LegionLeaseOwnerProcess; correct the milestone 3\n  markers; one function formats the bot folder line.\n- Parenthesize imports of four or more names; Optional over X | None.",
          "timestamp": "2026-11-24T07:05:48+02:00",
          "tree_id": "55e88b3c8a033d9ca22434563fab0f453cf17035",
          "url": "https://github.com/BlackGad/ps-legion-marketplace/commit/7fae00b111053e98f810968f73be0d05203d99ed"
        },
        "date": 1795497131203,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 14.3789528,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 1.0968019,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 23.1766166,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.9697603,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 21.0857106,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.324457,
            "unit": "s"
          },
          {
            "name": "windows / install-uv",
            "value": 8.3418412,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-uv (repeat)",
            "value": 0.9567506,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 29.2447601,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 10.718086,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 25.4885645,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 5.1704314,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 7.3044033,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 1.7723784,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 0.9896816,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.6151036,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 2.3497193,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.4393357,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 2.6057929,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.4061858,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 27.6177569,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 6.509711,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 25.7586836,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 17.8178299,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 18.4338842,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 18.522345,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 26.455791,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 6.8529083,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 12.2751604,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 1.1036461,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 9.0448634,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 1.2102932,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 18.7154855,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 1.0415015,
            "unit": "s"
          },
          {
            "name": "macos / install-uv",
            "value": 1.4514791,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-uv (repeat)",
            "value": 0.67879,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 12.7922097,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 6.6077395,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 24.453904,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 5.7661209,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 7.5434384,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 1.7684776,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 1.1176263,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.6465717,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 2.5009085,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 1.2094823,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 1.5880017,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 1.3744939,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 21.200755,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 4.6077577,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 28.074467,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 14.4681033,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 15.5461542,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 15.4157037,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 17.5585459,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 5.3210264,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 8.6266619,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.8174018,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 4.7456569,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.494374,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 3.455756,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.6322115,
            "unit": "s"
          },
          {
            "name": "linux / install-uv",
            "value": 1.0890545,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-uv (repeat)",
            "value": 0.4459393,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 10.0405996,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 5.8436585,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 11.9029692,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 2.6342513,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 3.5600307,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 0.9862866,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.5295398,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.3001125,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 0.8774584,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.5469465,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 0.9010954,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.5018741,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 13.4017504,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 3.11219,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 13.6593748,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 10.0719138,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 9.776339,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 9.1895409,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 12.076251,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 3.5134009,
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
          "id": "bdf312c5969c900a3c871da4a850a17d6067f52b",
          "message": "fix(python): close milestone 2 second review findings on lease, nudge and update (#60)",
          "timestamp": "2026-11-24T08:04:43+02:00",
          "tree_id": "6c9a40aa31358c5ddb015ebe911082c9cfe4094b",
          "url": "https://github.com/BlackGad/ps-legion-marketplace/commit/bdf312c5969c900a3c871da4a850a17d6067f52b"
        },
        "date": 1795500618032,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 12.8186878,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 0.8902407,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 17.7937271,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.7805624,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 15.3086002,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.2794911,
            "unit": "s"
          },
          {
            "name": "windows / install-uv",
            "value": 6.6907344,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-uv (repeat)",
            "value": 0.7610132,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 25.5238617,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 10.7596075,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 23.7490733,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 4.2642521,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 6.5816284,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 1.3926001,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 0.8678859,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.5531732,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 2.144002,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.3270122,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 2.3746857,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.2309162,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 26.1060384,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 6.3074192,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 24.7604437,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 16.3915517,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 17.1483332,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 16.754085,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 23.4557249,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 6.63953,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 10.4340271,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 1.179256,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 8.0970965,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 0.845261,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 6.4752692,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 1.3533903,
            "unit": "s"
          },
          {
            "name": "macos / install-uv",
            "value": 1.5785904,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-uv (repeat)",
            "value": 0.8250497,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 19.6035742,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 8.4718099,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 14.0113855,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 3.6670507,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 5.1063088,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 2.2038674,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 1.2082453,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.7576487,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 4.0538246,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 1.9917759,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 3.0019864,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 1.365338,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 28.2726797,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 5.4700264,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 19.0434266,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 11.2605462,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 12.3488976,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 12.4038463,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 14.5475554,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 4.4993468,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 12.2614351,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.4864027,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 4.8048519,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.4436542,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 3.647148,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.6023196,
            "unit": "s"
          },
          {
            "name": "linux / install-uv",
            "value": 1.133079,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-uv (repeat)",
            "value": 0.3905522,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 9.5194602,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 5.1657591,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 11.5553661,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 3.079385,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 3.5060557,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 0.9783752,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.5308446,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.2612252,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 0.898381,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.4463665,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 0.8289793,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.4098532,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 12.675207,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 3.1667913,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 12.8690009,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 8.8099346,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 9.2655092,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 8.6575456,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 11.3711771,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 3.4337343,
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
          "id": "4abf8fec704be087f5ab49042e068a33670382ff",
          "message": "test: close milestone 2 second review findings on fences, flaky tests and wording (#61)",
          "timestamp": "2026-11-24T08:18:29+02:00",
          "tree_id": "4f1ba4b8026619a9a8d1e269cf7c6d83ecf85712",
          "url": "https://github.com/BlackGad/ps-legion-marketplace/commit/4abf8fec704be087f5ab49042e068a33670382ff"
        },
        "date": 1795501476728,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 14.6860421,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 1.1110921,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 20.9621983,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.9681503,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 20.3451782,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.4031597,
            "unit": "s"
          },
          {
            "name": "windows / install-uv",
            "value": 8.9127065,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-uv (repeat)",
            "value": 0.9598392,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 35.4056462,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 10.7530247,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 25.6061009,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 5.4752975,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 7.5314532,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 1.6962025,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 1.041123,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.6473872,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 2.4666252,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.4500435,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 2.633488,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.4474912,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 27.9942277,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 6.7678317,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 27.5782407,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 18.6726653,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 19.5684298,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 20.4086081,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 24.5145464,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 7.1396197,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 12.5245184,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 1.8615545,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 12.8458665,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 1.2306618,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 6.6325113,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 1.1175382,
            "unit": "s"
          },
          {
            "name": "macos / install-uv",
            "value": 1.5828097,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-uv (repeat)",
            "value": 0.5769094,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 18.0087975,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 10.5518402,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 21.3081503,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 5.1083883,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 6.792596,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 1.5129022,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.9743101,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.6952325,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 2.468883,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 2.0998069,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 2.8497867,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 1.9974218,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 33.3258795,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 7.6558778,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 34.0469006,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 19.8259096,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 21.9315627,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 16.121628,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 19.5893039,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 6.649179,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 10.5680384,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.8718708,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 6.8945832,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.7237747,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 4.7691168,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.8422325,
            "unit": "s"
          },
          {
            "name": "linux / install-uv",
            "value": 1.3872265,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-uv (repeat)",
            "value": 0.624708,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 14.8921385,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 7.3901002,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 16.5282003,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 3.9928778,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 4.6021627,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 1.3128851,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.7576391,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.4007869,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 0.9963404,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.6567648,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 0.9921701,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.6443268,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 16.8119273,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 4.4851576,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 17.6724704,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 12.3268768,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 13.1285908,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 12.5398972,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 15.8276331,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 4.7409536,
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
          "id": "e5e68ddf5a84a8170bfe56a944c589fcce1bed3e",
          "message": "fix: close milestone 2 third review findings (#62)\n\n* fix: close milestone 2 third review findings\n\n* test(python): keep the Windows junction test typed on every platform",
          "timestamp": "2026-11-24T09:30:34+02:00",
          "tree_id": "8ceaa3d6b3390b19b783e46924cf6c102e0f97b2",
          "url": "https://github.com/BlackGad/ps-legion-marketplace/commit/e5e68ddf5a84a8170bfe56a944c589fcce1bed3e"
        },
        "date": 1795505774029,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 14.7274708,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 1.0641466,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 18.2614882,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.9292718,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 16.7906682,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.508224,
            "unit": "s"
          },
          {
            "name": "windows / install-uv",
            "value": 7.6798295,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-uv (repeat)",
            "value": 0.8810154,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 23.9889132,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 10.2595333,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 22.9687273,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 4.7782875,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 7.1204802,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 1.5710865,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 0.9666624,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.6025624,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 2.217074,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.3864997,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 2.3788307,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.2994585,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 27.8753406,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 6.4077083,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 26.1434659,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 17.5706511,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 18.4394491,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 17.550237,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 23.5686871,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 6.9101814,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 9.613918,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 0.7421356,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 6.1400767,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 0.7541564,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 4.3047822,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 0.8432444,
            "unit": "s"
          },
          {
            "name": "macos / install-uv",
            "value": 1.3951416,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-uv (repeat)",
            "value": 0.656613,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 12.9881133,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 5.7995296,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 13.101465,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 2.9711692,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 4.032855,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 1.0680571,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.6485949,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.4118915,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 2.1659646,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 1.183864,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 1.8918694,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 1.8052212,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 17.6009178,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 4.5806162,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 14.4520527,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 9.3525533,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 12.3794257,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 11.2062038,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 15.3729766,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 4.283145,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 12.5298455,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.4065908,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 4.655292,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.4414206,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 3.4713303,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.5714038,
            "unit": "s"
          },
          {
            "name": "linux / install-uv",
            "value": 0.944667,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-uv (repeat)",
            "value": 0.3915276,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 11.2186073,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 5.1121688,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 11.5025212,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 3.1272366,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 3.5006436,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 0.9710496,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.5062763,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.2518492,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 0.6469402,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.4040803,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 0.6636486,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.413501,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 12.3422509,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 3.1380314,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 12.7024222,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 8.6267382,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 9.1737151,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 8.7338702,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 11.3292771,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 3.4021379,
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
          "id": "acc89437c8746460c51b3557ee92e6c162676007",
          "message": "chore(main): release 0.15.0 (#50)\n\nCo-authored-by: github-actions[bot] <41898282+github-actions[bot]@users.noreply.github.com>",
          "timestamp": "2026-11-24T09:45:32+02:00",
          "tree_id": "7e332cf575237ac972d1825e2c202b0e06d7428e",
          "url": "https://github.com/BlackGad/ps-legion-marketplace/commit/acc89437c8746460c51b3557ee92e6c162676007"
        },
        "date": 1795506717915,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 14.5498721,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 1.0690243,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 18.5621467,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.9559708,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 19.5982348,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.3326467,
            "unit": "s"
          },
          {
            "name": "windows / install-uv",
            "value": 7.8706944,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-uv (repeat)",
            "value": 0.9045378,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 25.3047056,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 10.8679224,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 26.3088102,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 5.1461731,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 7.7908956,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 1.6637732,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 1.0473693,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.647754,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 2.3791165,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.4468979,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 2.6577185,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.4146282,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 29.1967122,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 6.6978136,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 27.408005,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 18.8507298,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 19.4042969,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 18.6986603,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 25.0864551,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 7.4312157,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 8.3246096,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 0.5428642,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 6.1385055,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 0.7913312,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 4.7309077,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 0.7180798,
            "unit": "s"
          },
          {
            "name": "macos / install-uv",
            "value": 1.20972,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-uv (repeat)",
            "value": 0.5157657,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 12.1935142,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 6.0604142,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 13.6608983,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 2.639897,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 3.966446,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 1.0020125,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.6478749,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.4613881,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 1.5614355,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 1.6983563,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 2.2063457,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 1.4265774,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 18.4141895,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 4.382765,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 19.2286462,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 11.0269634,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 11.666297,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 11.4160692,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 17.218827,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 4.5921822,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 7.7780565,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 1.2583775,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 7.1624638,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.7503185,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 4.6997799,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.8310327,
            "unit": "s"
          },
          {
            "name": "linux / install-uv",
            "value": 1.3341958,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-uv (repeat)",
            "value": 0.6088373,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 12.6655452,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 7.151034,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 17.3072718,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 3.8720871,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 4.455286,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 1.2658304,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.723977,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.3819338,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 0.9631944,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.6548539,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 0.9825883,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.6149353,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 16.6130821,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 4.3306761,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 16.903465,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 12.098233,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 12.8606858,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 12.0538902,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 15.0787298,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 4.6241648,
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
          "id": "5cc87f6b1305018f4d7b628e4da9fc4d068a07cc",
          "message": "chore(release): list refactors and tests in the release notes (#63)",
          "timestamp": "2026-11-24T10:08:05+02:00",
          "tree_id": "001a0288d586f63d169e53747e0b3c51cd97f350",
          "url": "https://github.com/BlackGad/ps-legion-marketplace/commit/5cc87f6b1305018f4d7b628e4da9fc4d068a07cc"
        },
        "date": 1795507962610,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 11.7321236,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 0.623816,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 15.1676151,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.5789825,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 16.2713304,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.0351192,
            "unit": "s"
          },
          {
            "name": "windows / install-uv",
            "value": 5.2185427,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-uv (repeat)",
            "value": 0.5528145,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 19.458013,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 6.432423,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 14.9015555,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 2.7843868,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 4.6872312,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 0.9025194,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 0.6037515,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.384427,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 1.4052879,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 0.8423368,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 1.5280273,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 0.8129661,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 18.266404,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 4.1299336,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 17.0384976,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 10.9985467,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 11.5640269,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 10.9942978,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 15.6157733,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 4.3786791,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 10.0130917,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 0.8754071,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 8.6771835,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 1.6894284,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 9.0804448,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 2.079858,
            "unit": "s"
          },
          {
            "name": "macos / install-uv",
            "value": 2.5724192,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-uv (repeat)",
            "value": 0.9346941,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 20.1488847,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 9.4399054,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 18.2570347,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 7.4674975,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 6.1824722,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 1.2178031,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.8289943,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.4052138,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 2.120231,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 1.2079583,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 1.747345,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 1.162048,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 21.3160573,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 4.3792181,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 21.0986499,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 12.7297448,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 14.1794507,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 14.9363839,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 20.3074869,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 5.6418401,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 14.728912,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.4106976,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 4.595998,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.4473864,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 3.5915198,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.5803204,
            "unit": "s"
          },
          {
            "name": "linux / install-uv",
            "value": 0.986711,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-uv (repeat)",
            "value": 0.3970005,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 10.9960811,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 5.1730033,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 11.7040895,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 3.0309601,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 3.4687774,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 0.973789,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.5117353,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.2599729,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 0.754338,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.4374167,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 1.1322983,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.4130283,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 12.3034912,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 3.1012579,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 12.8331973,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 8.6516636,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 9.1371472,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 8.6824119,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 11.4330287,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 3.4558516,
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
          "id": "1cc335e84a340eb372903fdf24b27eaf7add089e",
          "message": "feat(python): repository setup in Python (#64)\n\n* feat(python): repository setup in Python\n\n* fix(python): close task 1 review findings on repository setup",
          "timestamp": "2026-11-24T11:29:07+02:00",
          "tree_id": "2eb68281d4d6d5b1eb8bac930bec8cf581f516f6",
          "url": "https://github.com/BlackGad/ps-legion-marketplace/commit/1cc335e84a340eb372903fdf24b27eaf7add089e"
        },
        "date": 1795512894293,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 13.3033724,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 0.7896662,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 17.5241629,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.7658659,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 19.5009211,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.0901445,
            "unit": "s"
          },
          {
            "name": "windows / install-uv",
            "value": 6.379835,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-uv (repeat)",
            "value": 0.6697715,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 20.5880149,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 8.0791526,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 18.4786517,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 3.7547925,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 5.7180484,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 1.1897347,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 0.7677911,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.4774218,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 1.8282495,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.151903,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 2.5049541,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.3707288,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 21.4256463,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 5.1949381,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 21.0185612,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 14.732091,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 15.1803174,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 13.7192224,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 18.4759031,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 5.3787157,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 14.2874878,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 1.8196565,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 10.8691762,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 1.8399151,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 8.0000618,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 1.4072372,
            "unit": "s"
          },
          {
            "name": "macos / install-uv",
            "value": 2.2290811,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-uv (repeat)",
            "value": 1.1535167,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 22.207561,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 18.4784243,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 22.6746235,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 4.7233256,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 5.1126787,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 1.5263359,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.9427929,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.539635,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 1.3063853,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 0.6153498,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 1.354326,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 0.6686497,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 30.4250176,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 6.8462939,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 25.010213,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 16.8137085,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 21.115081,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 17.7369074,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 26.6564106,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 7.8659498,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 14.1534863,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.5041594,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 5.0784048,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.5462242,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 3.7537375,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.6752927,
            "unit": "s"
          },
          {
            "name": "linux / install-uv",
            "value": 1.0529269,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-uv (repeat)",
            "value": 0.5057753,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 10.3246077,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 5.8950872,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 13.3738539,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 3.0251716,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 3.6486082,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 1.0047888,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.593462,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.3228178,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 0.5774057,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.3311102,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 0.6268036,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.3454931,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 14.0067049,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 3.6742185,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 14.6323021,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 10.086406,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 10.8571236,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 10.1346634,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 12.8754169,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 3.8972658,
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
          "id": "ea156e0cdfa77e94626bbcd9dbeac5e4df31e918",
          "message": "feat(python): channels in Python (#65)\n\n* feat(python): channels in Python\n\n* fix(python): close task 2 review findings on channels and the settings writer\n\n* test(python): limit the injected cleanup failure to the settings temp file",
          "timestamp": "2026-11-24T12:16:03+02:00",
          "tree_id": "0c464e54900fa952fa0feef329c027e756d06fce",
          "url": "https://github.com/BlackGad/ps-legion-marketplace/commit/ea156e0cdfa77e94626bbcd9dbeac5e4df31e918"
        },
        "date": 1795515735925,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "windows / install-cli-claude",
            "value": 14.4122823,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-claude (repeat)",
            "value": 1.0540783,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-codex",
            "value": 17.5081359,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-codex (repeat)",
            "value": 0.8961472,
            "unit": "s"
          },
          {
            "name": "windows / install-cli-copilot",
            "value": 18.6173084,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-cli-copilot (repeat)",
            "value": 1.2942681,
            "unit": "s"
          },
          {
            "name": "windows / install-uv",
            "value": 7.2979898,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-uv (repeat)",
            "value": 0.8783329,
            "unit": "s"
          },
          {
            "name": "windows / install-legion",
            "value": 23.3713671,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / install-legion (repeat)",
            "value": 10.1249904,
            "unit": "s"
          },
          {
            "name": "windows / setup",
            "value": 23.7356435,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / setup (repeat)",
            "value": 4.8929747,
            "unit": "s"
          },
          {
            "name": "windows / add",
            "value": 7.333102,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / add (repeat)",
            "value": 1.7107977,
            "unit": "s"
          },
          {
            "name": "windows / remove",
            "value": 1.0713587,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / remove (repeat)",
            "value": 0.6577971,
            "unit": "s"
          },
          {
            "name": "windows / repo-private",
            "value": 2.5184538,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-private (repeat)",
            "value": 1.6065756,
            "unit": "s"
          },
          {
            "name": "windows / repo-shared",
            "value": 3.3998228,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / repo-shared (repeat)",
            "value": 1.7743931,
            "unit": "s"
          },
          {
            "name": "windows / uninstall",
            "value": 26.4589535,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / uninstall (repeat)",
            "value": 8.0597904,
            "unit": "s"
          },
          {
            "name": "windows / reinstall",
            "value": 29.8945909,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / reinstall (repeat)",
            "value": 18.510032,
            "unit": "s"
          },
          {
            "name": "windows / restore-launchers",
            "value": 19.8969646,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / restore-launchers (repeat)",
            "value": 18.4364012,
            "unit": "s"
          },
          {
            "name": "windows / purge",
            "value": 24.1923078,
            "unit": "s",
            "extra": "claude 2.1.330, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "windows / purge (repeat)",
            "value": 7.0634394,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-claude",
            "value": 15.0461634,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-claude (repeat)",
            "value": 0.8788724,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-codex",
            "value": 7.6556741,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-codex (repeat)",
            "value": 1.3231955,
            "unit": "s"
          },
          {
            "name": "macos / install-cli-copilot",
            "value": 5.8702935,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-cli-copilot (repeat)",
            "value": 1.3056727,
            "unit": "s"
          },
          {
            "name": "macos / install-uv",
            "value": 1.377351,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-uv (repeat)",
            "value": 0.6093654,
            "unit": "s"
          },
          {
            "name": "macos / install-legion",
            "value": 15.192216,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / install-legion (repeat)",
            "value": 7.9466836,
            "unit": "s"
          },
          {
            "name": "macos / setup",
            "value": 17.9574461,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / setup (repeat)",
            "value": 3.3841449,
            "unit": "s"
          },
          {
            "name": "macos / add",
            "value": 4.9364945,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / add (repeat)",
            "value": 1.1856552,
            "unit": "s"
          },
          {
            "name": "macos / remove",
            "value": 0.5660741,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / remove (repeat)",
            "value": 0.3133582,
            "unit": "s"
          },
          {
            "name": "macos / repo-private",
            "value": 0.9321235,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-private (repeat)",
            "value": 1.0610553,
            "unit": "s"
          },
          {
            "name": "macos / repo-shared",
            "value": 1.1452526,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / repo-shared (repeat)",
            "value": 0.6351099,
            "unit": "s"
          },
          {
            "name": "macos / uninstall",
            "value": 17.9927721,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / uninstall (repeat)",
            "value": 4.288919,
            "unit": "s"
          },
          {
            "name": "macos / reinstall",
            "value": 17.2077779,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / reinstall (repeat)",
            "value": 13.3430638,
            "unit": "s"
          },
          {
            "name": "macos / restore-launchers",
            "value": 12.6622613,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / restore-launchers (repeat)",
            "value": 11.1007707,
            "unit": "s"
          },
          {
            "name": "macos / purge",
            "value": 21.5455696,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "macos / purge (repeat)",
            "value": 6.9008505,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-claude",
            "value": 14.7187048,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-claude (repeat)",
            "value": 0.4095644,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-codex",
            "value": 4.6307458,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-codex (repeat)",
            "value": 0.4216222,
            "unit": "s"
          },
          {
            "name": "linux / install-cli-copilot",
            "value": 3.4755033,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-cli-copilot (repeat)",
            "value": 0.5406044,
            "unit": "s"
          },
          {
            "name": "linux / install-uv",
            "value": 1.2830098,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-uv (repeat)",
            "value": 0.3775291,
            "unit": "s"
          },
          {
            "name": "linux / install-legion",
            "value": 11.5829231,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / install-legion (repeat)",
            "value": 4.9138153,
            "unit": "s"
          },
          {
            "name": "linux / setup",
            "value": 11.1580631,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / setup (repeat)",
            "value": 2.943743,
            "unit": "s"
          },
          {
            "name": "linux / add",
            "value": 3.3037471,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / add (repeat)",
            "value": 0.9209814,
            "unit": "s"
          },
          {
            "name": "linux / remove",
            "value": 0.5054949,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / remove (repeat)",
            "value": 0.2384675,
            "unit": "s"
          },
          {
            "name": "linux / repo-private",
            "value": 0.4533478,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-private (repeat)",
            "value": 0.2648504,
            "unit": "s"
          },
          {
            "name": "linux / repo-shared",
            "value": 0.4579896,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / repo-shared (repeat)",
            "value": 0.269094,
            "unit": "s"
          },
          {
            "name": "linux / uninstall",
            "value": 11.8872001,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / uninstall (repeat)",
            "value": 3.017154,
            "unit": "s"
          },
          {
            "name": "linux / reinstall",
            "value": 12.3583143,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / reinstall (repeat)",
            "value": 8.3847716,
            "unit": "s"
          },
          {
            "name": "linux / restore-launchers",
            "value": 8.8750422,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / restore-launchers (repeat)",
            "value": 8.4082903,
            "unit": "s"
          },
          {
            "name": "linux / purge",
            "value": 10.8269636,
            "unit": "s",
            "extra": "claude 2.1.331, codex 0.172.0, copilot 1.0.114"
          },
          {
            "name": "linux / purge (repeat)",
            "value": 3.2605068,
            "unit": "s"
          }
        ]
      }
    ]
  }
}