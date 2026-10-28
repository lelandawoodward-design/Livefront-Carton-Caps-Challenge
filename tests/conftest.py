import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT))

from pipeline import steps  # noqa: E402
from pipeline.config import Paths  # noqa: E402


@pytest.fixture(scope='session')
def generated(tmp_path_factory) -> Paths:
    """Default-size generator output in a temp home, shared by the pipeline tests."""
    paths = Paths(tmp_path_factory.mktemp('home'))
    steps.generate(paths)
    return paths


def copy_home(source: Paths, target_dir: Path) -> Paths:
    """A fresh pipeline home with its own copy of the generated data."""
    import shutil
    target = Paths(target_dir)
    shutil.copytree(source.data, target.data)
    return target
