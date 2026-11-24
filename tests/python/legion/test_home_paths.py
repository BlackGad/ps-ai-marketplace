from pathlib import Path

import sys

from legion._home import full_path, is_under, owner_path_safe, resolve_directory, same_path

if sys.platform == "win32":
    import _winapi


def test_lexical_path_checks_keep_links_visible(tmp_path: Path) -> None:
    outside = tmp_path / "outside"
    outside.mkdir()
    home = tmp_path / "home"
    home.mkdir()
    link = home / "linked"
    if sys.platform == "win32":
        _winapi.CreateJunction(str(outside), str(link))
    else:
        link.symlink_to(outside, target_is_directory=True)
    assert is_under(link / "child", home)
    assert not owner_path_safe(link / "child", home)
    assert owner_path_safe(link, link)
    assert owner_path_safe(home / "missing", home)
    assert resolve_directory(link) == outside
    assert full_path(link / "..") == home
    assert same_path(home, home)
