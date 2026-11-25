from legion import cli as _cli


def run(arguments: list[str]) -> int:
    try:
        _cli.main(arguments, prog_name="legion")
    except SystemExit as result:
        # As Python itself exits: no code is 0, a message is 1.
        if result.code is None:
            return 0
        return result.code if isinstance(result.code, int) else 1
    return 0
