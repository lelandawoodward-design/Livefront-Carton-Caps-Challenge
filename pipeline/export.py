"""Export gold and quality tables to Parquet so any tool can read them."""

from pathlib import Path
from typing import List

from .config import Paths, connect_warehouse


def export_tables(paths: Paths, schemas=('gold', 'quality')) -> List[Path]:
    con = connect_warehouse(paths.warehouse)
    written = []
    try:
        tables = con.execute(
            "select table_schema, table_name from information_schema.tables "
            "where table_schema in ? and table_type = 'BASE TABLE' order by 1, 2",
            [list(schemas)]).fetchall()
        for schema, table in tables:
            target = paths.exports / schema / f'{table}.parquet'
            target.parent.mkdir(parents=True, exist_ok=True)
            con.execute(f"copy (select * from {schema}.{table}) to '{target}' (format parquet)")
            written.append(target)
    finally:
        con.close()
    return written
