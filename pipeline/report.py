"""Run analysis/sample_queries.sql and print each result as a table."""

import re
from decimal import Decimal
from typing import List, Tuple

from .config import REPO_ROOT, Paths, connect_warehouse

SAMPLE_QUERIES = REPO_ROOT / 'analysis' / 'sample_queries.sql'


def load_queries(path=SAMPLE_QUERIES) -> List[Tuple[str, str]]:
    """Split the file on '-- name:' lines into (name, sql) pairs."""
    text = path.read_text(encoding='utf-8')
    parts = re.split(r'^-- name:\s*(.+)$', text, flags=re.M)
    return [(name.strip(), sql.strip().rstrip(';')) for name, sql in zip(parts[1::2], parts[2::2])]


def _fmt(value) -> str:
    if value is None:
        return ''
    if isinstance(value, (float, Decimal)):
        return f'{value:,.4f}'.rstrip('0').rstrip('.') if value != int(value) else f'{int(value):,}'
    if isinstance(value, int) and not isinstance(value, bool):
        return f'{value:,}'
    return str(value)


def format_table(columns: List[str], rows: List[tuple]) -> str:
    cells = [[_fmt(v) for v in row] for row in rows]
    widths = [max([len(c)] + [len(r[i]) for r in cells]) for i, c in enumerate(columns)]
    line = lambda values: '  '.join(v.ljust(w) for v, w in zip(values, widths)).rstrip()
    return '\n'.join([line(columns), line(['-' * w for w in widths])] + [line(r) for r in cells])


def run_report(paths: Paths) -> str:
    con = connect_warehouse(paths.warehouse)
    out = []
    try:
        for name, sql in load_queries():
            result = con.execute(sql)
            columns = [d[0] for d in result.description]
            out.append(f'## {name}\n\n{format_table(columns, result.fetchall())}\n')
    finally:
        con.close()
    return '\n'.join(out)
