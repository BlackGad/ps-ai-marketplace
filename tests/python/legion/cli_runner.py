from legion import _cli


def run(arguments: list[str]) -> int:
    try:
        _cli.main(arguments, prog_name="legion")
    except SystemExit as result:
        return result.code if isinstance(result.code, int) else 0
    return 0
