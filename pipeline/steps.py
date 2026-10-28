"""The pipeline's steps, and the two end-to-end flows built from them."""

import shutil
import sys
import time
import warnings
from contextlib import contextmanager
from typing import Dict, List, Optional

from . import export, feed, ingest, transform
from .config import REPO_ROOT, Paths, connect_warehouse


@contextmanager
def _timed(label: str, timings: Dict[str, float]):
    start = time.perf_counter()
    print(f'\n==> {label}', flush=True)
    yield
    timings[label] = time.perf_counter() - start


def generate(paths: Paths, scale: float = 1.0) -> None:
    """Run the data generator into paths.data (removed first: its SQLite writer appends on rerun)."""
    if str(REPO_ROOT) not in sys.path:
        sys.path.insert(0, str(REPO_ROOT))
    from data_generator import CartonCapsDataGenerator

    if paths.data.exists():
        shutil.rmtree(paths.data)
    sizes = dict(
        n_schools=50 if scale <= 1 else min(round(50 * scale), 100),  # provided generator caps at 105
        n_users=round(1000 * scale),
        n_products=100,
        n_purchases=round(10000 * scale),
        n_referrals=round(1000 * scale),
    )
    with warnings.catch_warnings():
        warnings.simplefilter('ignore', DeprecationWarning)  # sqlite3 datetime adapter, Python 3.12+
        CartonCapsDataGenerator(output_dir=str(paths.data)).generate_all(**sizes)


def reset(paths: Paths) -> None:
    """Remove everything downstream of the generator's output."""
    for path in (paths.landing, paths.warehouse.parent, paths.exports):
        if path.exists():
            shutil.rmtree(path)


def run_all(paths: Paths, cadence: str = 'monthly', scale: float = 1.0, regenerate: bool = True) -> Dict[str, float]:
    """generate -> feed -> ingest -> dbt build -> export, from a clean warehouse."""
    timings: Dict[str, float] = {}
    reset(paths)
    if regenerate or not paths.data.exists():
        with _timed('generate', timings):
            generate(paths, scale)
    with _timed('feed', timings):
        batches = feed.build_batches(paths.data, paths.landing, cadence)
        print(f'{len(batches)} landing batches: {batches[0]} .. {batches[-1]}')
    with _timed('ingest', timings):
        summary = ingest.ingest(paths)
        print(f"loaded {len(summary['batches'])} batches: " +
              ', '.join(f'{k}={v:,}' for k, v in summary['rows'].items()))
    with _timed('transform (dbt build)', timings):
        transform.run_dbt(paths, 'build')
    with _timed('export', timings):
        files = export.export_tables(paths)
        print(f'{len(files)} tables written to {paths.exports}')
    print_summary(paths, timings)
    return timings


def print_summary(paths: Paths, timings: Dict[str, float]) -> None:
    con = connect_warehouse(paths.warehouse)
    try:
        q = lambda sql: con.execute(sql).fetchone()
        purchases = q("select count(*), count(*) filter (where dq_status = 'valid') from silver.purchases_checked")
        referrals = q("select count(*), count(*) filter (where dq_status = 'valid') from silver.referrals_checked")
        raised = q("select sum(dollars_raised) from gold.fct_purchases")[0]
        print('\n==> summary')
        print(f'purchases: {purchases[0]:,} records, {purchases[0] - purchases[1]:,} quarantined')
        print(f'referrals: {referrals[0]:,} invites, {referrals[0] - referrals[1]:,} quarantined')
        print(f'funds raised for schools: ${raised:,.2f}')
        print('timings: ' + ', '.join(f'{k} {v:.1f}s' for k, v in timings.items()))
        print(f'warehouse: {paths.warehouse}')
    finally:
        con.close()


COMPARE_SCHEMAS = ('silver', 'gold', 'quality')
VOLATILE_COLUMNS = {'evaluated_batch_id'}  # records when a row was last re-checked, which legitimately differs


def demo_incremental(paths: Paths, split_after: Optional[str] = None) -> bool:
    """
    Build batch by batch, then check the result equals a full rebuild.

    Uses its own folder (<home>/demo_incremental) so the main warehouse is untouched.
    Returns True when every table matches.
    """
    demo = Paths(paths.home / 'demo_incremental')
    if demo.home.exists():
        shutil.rmtree(demo.home)
    timings: Dict[str, float] = {}
    if not paths.data.exists():
        with _timed('generate', timings):
            generate(paths)
    shutil.copytree(paths.data, demo.data)

    batches = feed.build_batches(demo.data, demo.landing, 'monthly')
    split_after = split_after or batches[(len(batches) * 3) // 4 - 1]
    later = [b for b in batches if b > split_after]
    print(f'{len(batches)} monthly batches; first build through {split_after}, '
          f'then {len(later)} more ({later[0]} .. {later[-1]})')

    with _timed(f'ingest batches through {split_after} and build', timings):
        ingest.ingest(demo, upto=split_after)
        transform.run_dbt(demo, 'build', quiet=True)
    with _timed(f'ingest the remaining {len(later)} batches and build incrementally', timings):
        ingest.ingest(demo)
        transform.run_dbt(demo, 'build', quiet=True)
        _report_reevaluated(demo)

    tables = _snapshot(demo)
    with _timed('full rebuild from bronze', timings):
        transform.run_dbt(demo, 'build', full_refresh=True, quiet=True)
    mismatches = _compare(demo, tables)

    print('\n==> incremental vs full rebuild')
    for table, (only_incremental, only_full) in mismatches.items():
        status = 'match' if only_incremental == only_full == 0 else \
            f'DIFFERS ({only_incremental} rows only incremental, {only_full} only full)'
        print(f'{table:45s} {status}')
    ok = all(a == b == 0 for a, b in mismatches.values())
    print(f"\n{'All' if ok else 'NOT all'} {len(mismatches)} tables match a full rebuild.")
    return ok


def _report_reevaluated(demo: Paths) -> None:
    con = connect_warehouse(demo.warehouse)
    try:
        for table in ('purchases_checked', 'referrals_checked'):
            total, touched = con.execute(
                f"select count(*), count(*) filter (where evaluated_batch_id = "
                f"(select max(evaluated_batch_id) from silver.{table})) from silver.{table}").fetchone()
            print(f'{table}: re-evaluated {touched:,} of {total:,} records in the incremental run')
    finally:
        con.close()


def _columns(con, schema: str, table: str) -> List[str]:
    rows = con.execute("select column_name from information_schema.columns where table_schema = ? "
                       "and table_name = ? order by ordinal_position", [schema, table]).fetchall()
    return [r[0] for r in rows if r[0] not in VOLATILE_COLUMNS]


def _snapshot(demo: Paths) -> List[str]:
    """Copy every silver, gold and quality table into a 'compare' schema."""
    con = connect_warehouse(demo.warehouse)
    try:
        con.execute('create schema if not exists compare')
        tables = con.execute(
            "select table_schema || '.' || table_name from information_schema.tables "
            "where table_schema in ? and table_type = 'BASE TABLE' order by 1",
            [list(COMPARE_SCHEMAS)]).fetchall()
        names = [t[0] for t in tables]
        for name in names:
            schema, table = name.split('.')
            cols = ', '.join(f'"{c}"' for c in _columns(con, schema, table))
            con.execute(f'create or replace table compare."{schema}__{table}" as select {cols} from {name}')
        return names
    finally:
        con.close()


def _compare(demo: Paths, tables: List[str]) -> Dict[str, tuple]:
    con = connect_warehouse(demo.warehouse)
    try:
        results = {}
        for name in tables:
            schema, table = name.split('.')
            cols = ', '.join(f'"{c}"' for c in _columns(con, schema, table))
            snap = f'compare."{schema}__{table}"'
            only_incremental = con.execute(
                f'select count(*) from (select {cols} from {snap} except all select {cols} from {name})').fetchone()[0]
            only_full = con.execute(
                f'select count(*) from (select {cols} from {name} except all select {cols} from {snap})').fetchone()[0]
            results[name] = (only_incremental, only_full)
        return results
    finally:
        con.close()
