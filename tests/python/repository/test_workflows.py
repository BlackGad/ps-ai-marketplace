import re
import subprocess
import textwrap
from pathlib import Path

import pytest
from conftest import REPO

WORKFLOWS = REPO / ".github/workflows"
GATE_NAME = (
    "${{ (inputs.sha != '' || (github.event_name == 'pull_request' && github.event.pull_request.user.login == 'github-actions[bot]' "
    "&& startsWith(github.head_ref, 'release-please--'))) && 'release PR tests' || 'gate' }}"
)
PINNED_REF = "ref: ${{ inputs.sha || github.sha }}"


def job_blocks(workflow: str) -> dict[str, str]:
    # Match the repository's YAML indentation so action version comments stay available.
    section = re.search(r"(?ms)^jobs:[ \t]*\n(.*?)(?=^[^\s#]|\Z)", workflow)
    return dict(re.findall(r"(?ms)^  ([\w-]+):[ \t]*\n(.*?)(?=^  [\w-]+:|\Z)", section[1])) if section else {}


def job_name(job_id: str, body: str) -> str:
    name = re.search(r"(?m)^    name:[ \t]*(.+?)[ \t]*$", body)
    return name[1].strip("'\"") if name else job_id


def workflow_problems(workflow: str) -> list[str]:
    problems = []
    for value in re.findall(r"(?m)^[ \t]*(?:-[ \t]+)?uses:[ \t]*(.+?)[ \t]*$", workflow):
        if not value.startswith("./") and not re.match(r"[\w.-]+/[\w.-]+(/[^@\s]+)?@[0-9a-f]{40}\s+#\s*v\S*", value, re.IGNORECASE):
            problems.append(f"uses '{value}' is not pinned")
    if not re.search(r"(?mi)^permissions:", workflow):
        problems.append("no top-level permissions")
    for job_id, body in job_blocks(workflow).items():
        if not re.search(r"(?mi)^    (uses|timeout-minutes):", body):
            problems.append(f"job '{job_id}' has no timeout-minutes")
    return problems


@pytest.mark.parametrize(
    "value",
    ["actions/checkout@v5", "actions/checkout@main", f"actions/checkout@{'a' * 39}  # v5.0.0", f"actions/checkout@{'a' * 40}", "docker://alpine:3.20"],
)
def test_workflow_rejects_unpinned_actions(value: str) -> None:
    workflow = f"permissions: {{}}\njobs:\n  build:\n    timeout-minutes: 5\n    steps:\n      - uses: {value}\n"
    assert workflow_problems(workflow) == [f"uses '{value}' is not pinned"]


def test_workflow_check_requires_permissions_and_timeouts() -> None:
    workflow = f"permissions: {{}}\njobs:\n  build:\n    timeout-minutes: 5\n    steps:\n      - uses: actions/checkout@{'a' * 40}  # v5.0.0\n"
    assert workflow_problems(workflow) == []
    assert workflow_problems(workflow.removeprefix("permissions: {}\n")) == ["no top-level permissions"]
    assert workflow_problems(workflow.replace("permissions: {}\n", "").replace("  build:\n", "  build:\n    permissions: {}\n")) == ["no top-level permissions"]
    assert workflow_problems(workflow.replace("    timeout-minutes: 5\n", "")) == ["job 'build' has no timeout-minutes"]


def test_workflow_jobs_keep_order_and_names() -> None:
    workflow = """permissions: {}
jobs:
  call:
    uses: ./.github/workflows/tests.yml
  build:
    timeout-minutes: 5
    steps:
      - uses: ./local-action
"""
    assert workflow_problems(workflow) == []
    jobs = job_blocks(workflow)
    assert list(jobs) == ["call", "build"]
    assert [job_name(key, body) for key, body in jobs.items()] == ["call", "build"]
    named = """permissions: {}
jobs:
  build:
    name: 'gate'
    timeout-minutes: 5
    steps:
      - run: echo hi
  gate:
    name: another check
    timeout-minutes: 5
    steps:
      - name: step name must not replace the job name
        run: echo hi
"""
    jobs = job_blocks(named)
    assert list(jobs) == ["build", "gate"]
    assert [job_name(key, body) for key, body in jobs.items()] == ["gate", "another check"]
    with_comment = named.replace("  gate:", "# job boundary comment\n  gate:") + "\nconcurrency:\n  group: fixture\n"
    assert list(job_blocks(with_comment)) == ["build", "gate"]
    assert "concurrency:" not in job_blocks(with_comment)["gate"]


@pytest.mark.parametrize("file", sorted(WORKFLOWS.glob("*.yml")), ids=lambda path: path.name)
def test_repository_workflow_policy(file: Path) -> None:
    workflow = file.read_text(encoding="utf-8")
    assert workflow_problems(workflow) == []
    jobs = job_blocks(workflow)
    for reserved, owner in {"gate": "tests.yml", "integration": "integration.yml"}.items():
        if file.name != owner:
            assert reserved not in {key.lower() for key in jobs}
            assert reserved not in {job_name(key, body).lower() for key, body in jobs.items()}


def test_reusable_tests_checkout_the_requested_commit_with_read_only_permissions() -> None:
    tests = (WORKFLOWS / "tests.yml").read_text(encoding="utf-8")
    release = (WORKFLOWS / "release.yml").read_text(encoding="utf-8")
    jobs = job_blocks(tests)
    report = jobs["report"]
    assert not re.search(r"(?m)^\s+\w[\w-]*:\s*write\s*$", tests, re.IGNORECASE), "reusable tests must request no write permissions, even on skipped jobs"
    assert re.search(r"(?m)^          annotate_only: true\s*$", report, re.IGNORECASE), "reusable JUnit reporting must use read-only annotation mode"
    for job_id, body in [*jobs.items(), *job_blocks(release).items()]:
        if job_id != "integration-release-pr" and re.search(r"(?mi)^      [\w-]+: write\s*$", body):
            assert not re.search(r"uses: (actions/checkout@|\./)|(?:-File|\. )\s*(?:\./)?(?:tests|plugins)/", body, re.IGNORECASE), (
                f"privileged job '{job_id}' must not check out or execute repository scripts"
            )
    checkouts = [line for line in tests.splitlines() if "uses: actions/checkout@" in line.lower()]
    pinned_refs = [line for line in tests.splitlines() if line.strip().lower() == PINNED_REF.lower()]
    assert re.search(r"(?m)^    inputs:\n      sha:\s*$", tests, re.IGNORECASE), "reusable tests accept a sha input"
    assert not re.search(r"inputs\.ref", tests, re.IGNORECASE), "reusable tests must not resolve a moving ref input"
    assert len(checkouts) == len(pinned_refs) == 2, "every test checkout uses the supplied sha or the triggering commit"
    assert job_name("gate", jobs["gate"]) == GATE_NAME, "gate displays exactly gate for ordinary PRs and a separate name for bot release PRs and reusable calls"
    for job_id, body in jobs.items():
        if job_id != "gate":
            assert job_name(job_id, body).lower() not in {"gate", "integration"}, f"job '{job_id}' must not display a reserved required check name"


def test_release_checks_use_the_trusted_resolved_head() -> None:
    release = (WORKFLOWS / "release.yml").read_text(encoding="utf-8")
    jobs = job_blocks(release)
    resolve = jobs["resolve-release-pr"]
    call = jobs["test-release-pr"]
    mark = jobs["mark-release-pr"]
    integration_call = jobs["integration-release-pr"]
    assert "PR_NUMBER: ${{ fromJSON(needs.release-please.outputs.pr).number }}" in resolve, "trusted resolution uses the action output PR number"
    assert re.search(r"gh api \"repos/\$env:REPOSITORY/pulls/\$env:PR_NUMBER\"", resolve, re.IGNORECASE), "trusted resolution reads the PR through the API"
    # Trusted resolution validates the open PR and its full head sha.
    assert re.search(r"\$pr\.state -ne 'open'", resolve, re.IGNORECASE)
    assert re.search(r"\$pr\.head\.sha", resolve, re.IGNORECASE)
    assert "'^[0-9a-f]{40}$'" in resolve
    assert "sha: ${{ steps.head.outputs.sha }}" in resolve, "trusted job exposes the resolved head sha"
    assert not re.search(r"actions/checkout@", resolve, re.IGNORECASE), "trusted head resolution never checks out PR code"
    # Release tests depend on and use the resolved head sha.
    assert re.search(r"needs: resolve-release-pr", call, re.IGNORECASE)
    assert "sha: ${{ needs.resolve-release-pr.outputs.sha }}" in call
    assert not re.search(r"headBranchName|needs\.test-release-pr\.outputs\.sha", release, re.IGNORECASE), "release tests and statuses never derive the revision from a branch or matrix output"
    # Status publisher uses the same trusted sha even when checkout fails.
    assert re.search(r"needs: \[resolve-release-pr, test-release-pr, integration-release-pr\]", mark, re.IGNORECASE)
    assert "SHA: ${{ needs.resolve-release-pr.outputs.sha }}" in mark
    # Status publisher fails clearly when trusted sha resolution fails.
    assert re.search(r"if: always\(\) && needs\.resolve-release-pr\.result != 'skipped'", mark, re.IGNORECASE)
    assert "'^[0-9a-f]{40}$'" in mark
    assert re.search(r"missing or invalid release PR head SHA", mark, re.IGNORECASE)
    # Trusted publisher marks success or failure on the resolved head with context gate.
    assert re.search(r"statuses/\$env:SHA", mark, re.IGNORECASE)
    assert re.search(r"context=gate", mark, re.IGNORECASE)
    assert re.search(r"RESULT -eq 'success'", mark, re.IGNORECASE)
    assert re.search(r"else \{ 'failure' \}", mark, re.IGNORECASE)
    # Release integration uses the same trusted resolved head SHA.
    assert re.search(r"needs: resolve-release-pr", integration_call, re.IGNORECASE)
    assert "sha: ${{ needs.resolve-release-pr.outputs.sha }}" in integration_call
    assert re.search(r"uses: \./.github/workflows/integration.yml", integration_call, re.IGNORECASE)
    # Release caller grants only the callee permission ceiling and cannot execute code itself.
    assert re.search(r"contents: write", integration_call, re.IGNORECASE)
    assert re.search(r"pages: write", integration_call, re.IGNORECASE)
    assert not re.search(r"steps:|runs-on:", integration_call, re.IGNORECASE)
    # Trusted status publisher reports the integration result independently on the resolved SHA.
    assert re.search(r"context=integration", mark, re.IGNORECASE)
    assert "INTEGRATION_RESULT: ${{ needs.integration-release-pr.result }}" in mark
    assert re.search(r"INTEGRATION_RESULT -eq 'success'", mark, re.IGNORECASE)


def test_integration_runs_the_matrix_and_publishes_only_trusted_timings() -> None:
    integration = (WORKFLOWS / "integration.yml").read_text(encoding="utf-8")
    jobs = job_blocks(integration)
    writers = [job_id for job_id, body in jobs.items() if re.search(r"(?mi)^      contents: write\s*$", body)]
    assert writers == ["save-trend"], "only save-trend may write contents"
    for job_id, body in jobs.items():
        if job_id != "save-trend":
            assert not re.search(r"(?m)^      [\w-]+: write\s*$", body, re.IGNORECASE), f"integration job '{job_id}' is read-only"
    save = jobs["save-trend"]
    save_condition = (
        "needs.run.result == 'success' && needs.report.result == 'success' && needs.report.outputs.complete == 'true' "
        "&& (github.event_name == 'push' || github.event_name == 'schedule') && github.ref == 'refs/heads/main' && inputs.sha == ''"
    )
    run = jobs["run"]
    report = jobs["report"]
    assert f"if: {save_condition}" in save, "saving requires a complete successful matrix and a direct push or schedule on main with no checkout input"
    assert re.search(r"needs: \[run, report\]", save, re.IGNORECASE), "save-trend depends on both matrix and reporting"
    # Main writers serialize without evicting pending saves.
    assert re.search(r"group: integration-main-writer", save, re.IGNORECASE)
    assert re.search(r"queue: max", save, re.IGNORECASE)
    assert re.search(r"cancel-in-progress: false", save, re.IGNORECASE)
    assert "group: integration-${{ github.event_name }}-${{ inputs.sha || github.ref }}" in integration, "weekly concurrency is separate from pushes and release calls"
    assert "queue: ${{ github.event_name == 'pull_request' && 'single' || 'max' }}" in integration, "non-PR workflow runs retain pending runs"
    # Integration has PR, weekly, dispatch and reusable triggers.
    assert re.search(r"types: \[opened, synchronize, reopened\]", integration, re.IGNORECASE)
    assert re.search(r"cron: '0 3 \* \* 1'", integration, re.IGNORECASE)
    assert re.search(r"workflow_dispatch:", integration, re.IGNORECASE)
    assert re.search(r"workflow_call:", integration, re.IGNORECASE)
    # Integration matrix uses all three systems with independent timeouts.
    assert re.search(r"os: \[windows-2025, macos-15, ubuntu-24.04\]", run, re.IGNORECASE)
    assert re.search(r"fail-fast: false", run, re.IGNORECASE)
    assert re.search(r"timeout-minutes: 30", run, re.IGNORECASE)
    assert "ref: ${{ inputs.sha || github.sha }}" in run, "matrix tests the supplied immutable SHA"
    assert "ALLOW_SOURCE_FALLBACK: ${{ github.event_name == 'push' && github.ref == 'refs/heads/main' && inputs.sha == '' }}" in run, (
        "published-source fallback is allowed only on direct main pushes without a checkout input"
    )
    # Matrix selects Python 3.12 with uv before running the integration harness and converts Windows paths.
    assert 'python="$(uv python find --no-project 3.12)"' in run
    assert 'python="$(cygpath -u "$python")"' in run
    assert '"$python" tests/integration/run.py --out results "${args[@]}"' in run
    assert not re.search(r"uv run --no-project|tests/integration/run.ps1", run, re.IGNORECASE)
    # Matrix bootstraps uv using each root installer.
    assert not re.search(r"astral-sh/setup-uv@", run, re.IGNORECASE)
    assert re.search(r"install\.sh --yes", run, re.IGNORECASE)
    assert re.search(r"powershell\.exe -NoProfile -File.*install\.ps1", run, re.IGNORECASE)
    assert re.search(r"if: github.event_name == 'pull_request'\r?\n        uses: actions/cache/restore@", run, re.IGNORECASE), "npm downloads restore only on PRs and save only on the weekly main run"
    assert re.search(r"if: github.event_name == 'schedule' && github.ref == 'refs/heads/main' && inputs.sha == ''\r?\n        uses: actions/cache/save@", run, re.IGNORECASE), (
        "npm downloads restore only on PRs and save only on the weekly main run"
    )
    # Matrix preserves reports and logs for 90 days even on failure.
    assert re.search(r"if: always\(\)", run, re.IGNORECASE)
    assert re.search(r"retention-days: 90", run, re.IGNORECASE)
    # Report runs after failures without check-writing permissions.
    assert re.search(r"if: always\(\)", report, re.IGNORECASE)
    assert re.search(r"annotate_only: true", report, re.IGNORECASE)
    assert "python3 tests/integration/merge_benchmarks.py results integration-bench.json" in report, "report merges the per-system timings with the Python merger"
    for option in ("auto-push: false", "save-data-file: false", "comment-on-alert: false", "summary-always: true", "alert-threshold: '200%'", "fail-on-alert: false"):
        assert option in report, f"compare-only reporting sets {option}"
    for option in ("auto-push: true", "save-data-file: true", "comment-on-alert: true", "alert-threshold: '200%'", "fail-on-alert: false"):
        assert option in save, f"main trend sets {option}"
    gate = jobs["integration"]
    integration_name = GATE_NAME.replace("release PR tests", "release PR integration").replace("|| 'gate'", "|| 'integration'")
    # Comparison handles the first run before gh-pages exists.
    assert re.search(r"ls-remote --exit-code --heads origin refs/heads/gh-pages", report, re.IGNORECASE)
    assert re.search(r"No timing baseline yet", report, re.IGNORECASE)
    # Publisher has a trusted checkout and never runs PR scripts.
    assert re.search(r"uses: actions/checkout@", save, re.IGNORECASE)
    assert "ref: ${{ github.sha }}" in save
    assert not re.search(r"inputs.sha \|\| github.sha|(?:-File|\. )\s*(?:\./)?(?:tests|plugins)/", save, re.IGNORECASE)
    # Publisher bootstraps gh-pages idempotently without replacing the source checkout.
    assert re.search(r"ls-remote --exit-code --heads origin refs/heads/gh-pages", save, re.IGNORECASE)
    assert re.search(r"git commit-tree", save, re.IGNORECASE)
    assert re.search(r"git push origin .*refs/heads/gh-pages", save, re.IGNORECASE)
    # Publisher explicitly requests a Pages build after saving.
    assert re.search(r"pages: write", save, re.IGNORECASE)
    assert re.search(r"gh api --method POST \"repos/\$env:REPOSITORY/pages/builds\"", save, re.IGNORECASE)
    assert job_name("integration", gate) == integration_name, "ordinary PRs display integration and bot release PRs reserve the required status context"
    # Integration gate fails when the matrix fails or is cancelled.
    assert re.search(r"needs: run", gate, re.IGNORECASE)
    assert re.search(r"RUN_RESULT\" != success", gate, re.IGNORECASE)


def test_inline_integration_scripts_use_env_and_powershell_parses(pwsh_path: Path) -> None:
    integration = (WORKFLOWS / "integration.yml").read_text(encoding="utf-8")
    scripts = re.findall(r"(?m)^        run: \|\n((?:^          [^\n]*(?:\n|$)|^\n)*)", integration)
    assert scripts
    parse = (
        "$errors = $null\n[void][Management.Automation.Language.Parser]::ParseInput([Console]::In.ReadToEnd(), [ref]$null, [ref]$errors)\nif ($errors) { $errors | Out-String | Write-Output; exit 1 }"
    )
    for body in scripts:
        script = textwrap.dedent(body)
        assert "${{" not in script
        # The workflow's three Bash blocks are checked for interpolation above.
        if re.search(r'(?m)^(echo "npm_config_cache=|args=\(\)|if \[ "\$RUN_RESULT")', script):
            continue
        result = subprocess.run(
            [str(pwsh_path), "-NoProfile", "-NonInteractive", "-Command", parse],
            input=script,
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
        assert result.returncode == 0, result.stdout + result.stderr
