import json
import re

from conftest import REPO
from test_workflows import WORKFLOWS, job_blocks


def test_release_please_versions_all_three_manifests() -> None:
    config = json.loads((REPO / "release-please-config.json").read_text(encoding="utf-8"))
    manifest = json.loads((REPO / ".release-please-manifest.json").read_text(encoding="utf-8"))
    package = config["packages"]["."]
    assert re.fullmatch(r"\d+\.\d+\.\d+", manifest["."])
    assert package["release-type"] == "simple"
    assert package["include-component-in-tag"] is False
    files = package["extra-files"]
    assert sorted(file["path"] for file in files) == [
        "plugins/legion/.claude-plugin/plugin.json",
        "plugins/legion/.codex-plugin/plugin.json",
        "plugins/legion/plugin.json",
    ]
    for file in files:
        assert file["type"] == "json"
        assert file["jsonpath"] == "$.version"
        plugin = json.loads((REPO / file["path"]).read_text(encoding="utf-8"))
        assert plugin["version"] == manifest["."]


def test_stable_moves_to_the_released_commit_without_force_or_checkout() -> None:
    release = (WORKFLOWS / "release.yml").read_text(encoding="utf-8")
    stable = job_blocks(release)["stable"]
    assert re.search(r"(?m)^    needs: release-please\s*$", stable)
    assert "if: needs.release-please.outputs.release_created == 'true'" in stable
    assert re.search(r"(?m)^    permissions:\n      contents: write\n(?!      )", stable)
    assert re.search(r"(?m)^    timeout-minutes:", stable)
    assert not re.search(r"actions/checkout|(?:-File|\. )\s*(?:\./)?(?:tests|plugins)/", stable, re.IGNORECASE)
    assert "sha: ${{ steps.release.outputs.sha }}" in release
    assert "SHA: ${{ needs.release-please.outputs.sha }}" in stable
    assert "'^[0-9a-f]{40}$'" in stable
    assert "refs/heads/stable" in stable
    assert "force=false" in stable
    assert "git/refs" in stable
    assert not re.search(r"--force|force=true|CHANGELOG|version", stable, re.IGNORECASE)
