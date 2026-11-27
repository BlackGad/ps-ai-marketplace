from pathlib import Path

_module = Path(__file__).resolve()
_wheel_data = _module.parents[1] / "_plugin_data"
# A wheel bundles its resources inside the package. Editable installs and hooks use the plugin tree.
PLUGIN_ROOT = _wheel_data if _wheel_data.is_dir() else _module.parents[3]
