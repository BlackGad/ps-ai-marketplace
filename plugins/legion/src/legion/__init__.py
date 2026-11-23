def main() -> None:
    from ._cli import main as cli_main  # noqa: PLC0415

    cli_main()


__all__ = ["main"]
