"""Run the dbt project against the pipeline's DuckDB warehouse."""

import os
from typing import List, Optional

from .config import DBT_PROJECT_DIR, Paths


class TransformError(RuntimeError):
    """dbt reported a failed model or test."""


def run_dbt(paths: Paths, command: str = 'build', full_refresh: bool = False,
            select: Optional[List[str]] = None, quiet: bool = False) -> None:
    """Invoke dbt in-process. Raises TransformError if any node fails."""
    from dbt.cli.main import dbtRunner  # imported lazily: dbt is slow to import

    os.environ['CARTON_CAPS_WAREHOUSE'] = str(paths.warehouse)
    args = [command, '--project-dir', str(DBT_PROJECT_DIR), '--profiles-dir', str(DBT_PROJECT_DIR)]
    if full_refresh:
        args.append('--full-refresh')
    if select:
        args += ['--select', *select]
    if quiet:
        args += ['--quiet']
    try:
        result = dbtRunner().invoke(args)
    finally:
        _release_warehouse()
    if not result.success:
        raise TransformError(f'dbt {command} failed: {result.exception or "see output above"}')


def _release_warehouse() -> None:
    """
    Close the DuckDB instance dbt-duckdb keeps open in this process after a run.

    Otherwise the warehouse file stays open until Python exits. Windows refuses to
    delete an open file, so a later step in the same process (a reset, the
    incremental demo, the test suite) would fail with "file in use".
    """
    from dbt.adapters.duckdb.connections import DuckDBConnectionManager
    with DuckDBConnectionManager._LOCK:
        env = DuckDBConnectionManager._ENV
        if env is not None:
            env.close()
            DuckDBConnectionManager._ENV = None
