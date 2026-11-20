window.BENCHMARK_DATA = {
  "lastUpdate": 1795215388305,
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
      }
    ]
  }
}