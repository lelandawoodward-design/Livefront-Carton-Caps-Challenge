"""
Load landing batches into the bronze schema, exactly once per file.

* Batches load in date order, each in its own transaction: a batch either
  lands completely or not at all.
* A file is skipped if its path is already in meta.ingested_files with the
  same SHA-256. A file whose content changed after it was ingested is
  rejected rather than loaded twice.
* The header must contain exactly the contract's columns (any order); a
  missing or extra column rejects the whole batch (schema drift).
* Every value lands as VARCHAR. Type problems are handled in silver as
  data-quality issues, so nothing is lost at ingest.
"""

import csv
import hashlib
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional

import duckdb

from .config import CONTRACTS, Paths, connect_warehouse


class IngestError(RuntimeError):
    """A batch was rejected; nothing from it was loaded."""


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            digest.update(chunk)
    return digest.hexdigest()


def _header(path: Path) -> List[str]:
    with open(path, newline='', encoding='utf-8') as f:
        return next(csv.reader(f), [])


def ensure_tables(con: duckdb.DuckDBPyConnection) -> None:
    con.execute("create schema if not exists meta")
    con.execute("create schema if not exists bronze")
    con.execute("""
        create table if not exists meta.ingested_files (
            file_path varchar primary key, batch_id date, entity varchar,
            sha256 varchar, row_count bigint, ingested_at timestamp)""")
    con.execute("""
        create table if not exists meta.ingestion_log (
            logged_at timestamp, batch_id date, entity varchar, file_path varchar,
            status varchar, row_count bigint, message varchar)""")
    for entity, columns in CONTRACTS.items():
        cols = ', '.join(f'"{c}" varchar' for c in columns)
        con.execute(f"""
            create table if not exists bronze.{entity} (
                {cols}, _batch_id date, _source_file varchar,
                _row_number bigint, _ingested_at timestamp)""")


def _log(con, batch_id, entity, file_path, status, row_count=None, message=None) -> None:
    con.execute("insert into meta.ingestion_log values (?, ?, ?, ?, ?, ?, ?)",
                [datetime.now(), batch_id, entity, file_path, status, row_count, message])


def ingest(paths: Paths, upto: Optional[str] = None) -> Dict:
    """
    Load every landing batch not yet ingested, oldest first.

    Args:
        paths: pipeline locations
        upto: optional batch id (YYYY-MM-DD); later batches are left for a later run

    Returns:
        {'batches': [batch ids loaded], 'rows': {entity: rows loaded}}
    """
    paths.warehouse.parent.mkdir(parents=True, exist_ok=True)
    con = connect_warehouse(paths.warehouse)
    try:
        ensure_tables(con)
        summary = {'batches': [], 'rows': {entity: 0 for entity in CONTRACTS}}
        batch_dirs = sorted(d for d in paths.landing.glob('batch=*') if d.is_dir())
        for batch_dir in batch_dirs:
            batch_id = batch_dir.name.split('=', 1)[1]
            if upto and batch_id > upto:
                break
            loaded = _ingest_batch(con, paths.landing, batch_dir, batch_id)
            if loaded:
                summary['batches'].append(batch_id)
                for entity, n in loaded.items():
                    summary['rows'][entity] += n
        return summary
    finally:
        con.close()


def _ingest_batch(con, landing: Path, batch_dir: Path, batch_id: str) -> Dict[str, int]:
    pending = []
    for entity, contract in CONTRACTS.items():
        path = batch_dir / f'{entity}.csv'
        if not path.exists():
            continue
        rel = path.relative_to(landing).as_posix()
        digest = _sha256(path)
        prior = con.execute("select sha256 from meta.ingested_files where file_path = ?", [rel]).fetchone()
        if prior:
            if prior[0] != digest:
                _reject(con, batch_id, entity, rel, 'file content changed after it was ingested')
            continue
        header = _header(path)
        missing, extra = set(contract) - set(header), set(header) - set(contract)
        if missing or extra or len(header) != len(set(header)):
            _reject(con, batch_id, entity, rel,
                    f'header does not match contract (missing={sorted(missing)}, extra={sorted(extra)})')
        pending.append((entity, path, rel, digest))

    if not pending:
        return {}

    ingested_at = datetime.now()
    loaded = {}
    con.begin()
    try:
        for entity, path, rel, digest in pending:
            columns = ', '.join(f'"{c}"' for c in CONTRACTS[entity])
            con.execute(f"""
                insert into bronze.{entity}
                select {columns}, ?::date, ?, ordinality, ?
                from read_csv(?, header = true, all_varchar = true) with ordinality""",
                        [batch_id, rel, ingested_at, str(path)])
            rows = con.execute(f"select count(*) from bronze.{entity} where _source_file = ?", [rel]).fetchone()[0]
            con.execute("insert into meta.ingested_files values (?, ?, ?, ?, ?, ?)",
                        [rel, batch_id, entity, digest, rows, ingested_at])
            loaded[entity] = rows
        con.commit()
    except Exception as exc:
        con.rollback()
        _reject(con, batch_id, None, str(batch_dir), f'load failed: {exc}')
    for entity, path, rel, _ in pending:
        _log(con, batch_id, entity, rel, 'loaded', loaded[entity])
    return loaded


def _reject(con, batch_id, entity, file_path, message):
    _log(con, batch_id, entity, file_path, 'rejected', None, message)
    raise IngestError(f'batch {batch_id} rejected ({file_path}): {message}')
