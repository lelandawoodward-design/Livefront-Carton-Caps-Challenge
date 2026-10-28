"""
An offline viewer for a DuckDB file: browse schemas and tables, and run read-only SQL,
in your browser. Needs only Python and the duckdb package; nothing is downloaded.

    python view_warehouse.py                        # opens warehouse/carton_caps.duckdb
    python view_warehouse.py path/to/other.duckdb   # any DuckDB file
    python view_warehouse.py --port 8800 --no-browser

Each query opens the file read-only and closes it straight after, so the pipeline can
rebuild the warehouse while the viewer is open. Only this computer can reach the page
(it listens on 127.0.0.1). Stop it with Ctrl+C.
"""

import argparse
import datetime
import decimal
import json
import math
import sys
import threading
import time
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import duckdb

MAX_ROWS = 1000                     # rows sent to the page per query
SCHEMA_ORDER = ('gold', 'quality', 'silver', 'bronze', 'meta')


def open_read_only(db_path: Path) -> duckdb.DuckDBPyConnection:
    # enable_external_access=False: queries can read this database but no other files.
    return duckdb.connect(str(db_path), read_only=True, config={'enable_external_access': False})


def friendly_error(exc: Exception) -> str:
    message = str(exc)
    if 'lock' in message.lower():
        return ('The warehouse is busy: another program is writing to it (probably the pipeline). '
                'Try again when it finishes.\n\n' + message)
    return message


def display(value):
    """A cell value as text for the page (None stays None and shows as NULL)."""
    if value is None:
        return None
    if isinstance(value, float):
        return str(value) if not math.isfinite(value) else str(round(value, 6))
    if isinstance(value, datetime.datetime):
        return value.isoformat(sep=' ')
    if isinstance(value, (datetime.date, datetime.time)):
        return value.isoformat()
    if isinstance(value, (list, dict, tuple)):
        return json.dumps(value, default=str)
    if isinstance(value, (decimal.Decimal, bytes)) or not isinstance(value, (str, int, bool)):
        return str(value)
    return str(value) if isinstance(value, bool) else value


def catalog(db_path: Path) -> dict:
    con = open_read_only(db_path)
    try:
        tables = con.execute("""
            select schema_name, table_name, 'table' as kind, estimated_size
            from duckdb_tables() where not internal and not temporary
            union all
            select schema_name, view_name, 'view', null
            from duckdb_views() where not internal and not temporary
        """).fetchall()
    finally:
        con.close()
    rank = {name: i for i, name in enumerate(SCHEMA_ORDER)}
    tables.sort(key=lambda t: (rank.get(t[0], len(rank)), t[0], t[1]))
    schemas: dict = {}
    for schema, name, kind, rows in tables:
        schemas.setdefault(schema, []).append({'name': name, 'kind': kind, 'rows': rows})
    return {'database': db_path.name, 'schemas': [{'name': s, 'tables': t} for s, t in schemas.items()]}


def run_query(db_path: Path, sql: str) -> dict:
    started = time.perf_counter()
    con = open_read_only(db_path)
    try:
        cursor = con.execute(sql)
        if cursor.description is None:
            columns, rows, truncated = [], [], False
        else:
            columns = [{'name': d[0], 'type': str(d[1])} for d in cursor.description]
            rows = cursor.fetchmany(MAX_ROWS + 1)
            truncated = len(rows) > MAX_ROWS
            rows = [[display(v) for v in row] for row in rows[:MAX_ROWS]]
    finally:
        con.close()
    return {'columns': columns, 'rows': rows, 'truncated': truncated, 'max_rows': MAX_ROWS,
            'elapsed_ms': round((time.perf_counter() - started) * 1000)}


def make_handler(db_path: Path):
    class Handler(BaseHTTPRequestHandler):
        def _send(self, status: int, body: bytes, content_type: str) -> None:
            self.send_response(status)
            self.send_header('Content-Type', content_type)
            self.send_header('Content-Length', str(len(body)))
            self.send_header('Cache-Control', 'no-store')
            self.end_headers()
            self.wfile.write(body)

        def _json(self, status: int, payload: dict) -> None:
            self._send(status, json.dumps(payload).encode('utf-8'), 'application/json; charset=utf-8')

        def do_GET(self):
            if self.path in ('/', '/index.html'):
                self._send(200, PAGE.encode('utf-8'), 'text/html; charset=utf-8')
            elif self.path == '/api/catalog':
                try:
                    self._json(200, catalog(db_path))
                except Exception as exc:          # file missing, locked, not a DuckDB file
                    self._json(200, {'error': friendly_error(exc)})
            else:
                self._send(404, b'not found', 'text/plain')

        def do_POST(self):
            if self.path != '/api/query':
                self._send(404, b'not found', 'text/plain')
                return
            try:
                length = int(self.headers.get('Content-Length', 0))
                sql = json.loads(self.rfile.read(length) or b'{}').get('sql', '')
                self._json(200, run_query(db_path, sql))
            except Exception as exc:
                self._json(200, {'error': friendly_error(exc)})

        def log_message(self, *args):     # keep the terminal quiet
            pass
    return Handler


def main() -> None:
    parser = argparse.ArgumentParser(description='Browse a DuckDB file in your browser, offline and read-only.')
    parser.add_argument('database', nargs='?', default='warehouse/carton_caps.duckdb')
    parser.add_argument('--port', type=int, default=8765)
    parser.add_argument('--no-browser', action='store_true', help="don't open a browser tab")
    args = parser.parse_args()

    db_path = Path(args.database).resolve()
    if not db_path.exists():
        sys.exit(f'No database at {db_path}. Run the pipeline first (python -m pipeline run), '
                 'or pass the path to a DuckDB file.')
    try:
        server = ThreadingHTTPServer(('127.0.0.1', args.port), make_handler(db_path))
    except OSError:                           # port taken: let the system pick a free one
        server = ThreadingHTTPServer(('127.0.0.1', 0), make_handler(db_path))
    url = f'http://127.0.0.1:{server.server_address[1]}/'
    print(f'Viewing {db_path}\nOpen {url}  (Ctrl+C to stop)')
    if not args.no_browser:
        threading.Timer(0.5, webbrowser.open, [url]).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


PAGE = r"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Warehouse viewer</title>
<style>
:root {
  --bg: #f7f7f5; --panel: #ffffff; --text: #1d1d1b; --muted: #6b6b66; --line: #e3e2dd;
  --accent: #2f6f62; --accent-soft: #e4efec; --error-bg: #fbeceb; --error: #9b2c22;
  --mono: ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace;
  --sans: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #161716; --panel: #1e1f1e; --text: #e8e7e3; --muted: #9a9993; --line: #2e2f2d;
    --accent: #7cc2b1; --accent-soft: #23332f; --error-bg: #3a1f1c; --error: #f0a59c;
  }
}
* { box-sizing: border-box; }
html, body { height: 100%; margin: 0; }
body { background: var(--bg); color: var(--text); font: 14px/1.45 var(--sans); display: flex; flex-direction: column; }
header { display: flex; align-items: baseline; gap: 12px; padding: 10px 16px; border-bottom: 1px solid var(--line); background: var(--panel); }
header h1 { font-size: 15px; margin: 0; font-weight: 600; }
header .db { color: var(--muted); font-family: var(--mono); font-size: 12.5px; }
.app { flex: 1; display: grid; grid-template-columns: 300px 1fr; min-height: 0; }
aside { border-right: 1px solid var(--line); background: var(--panel); display: flex; flex-direction: column; min-height: 0; }
aside input { margin: 12px; padding: 7px 10px; border: 1px solid var(--line); border-radius: 6px; background: var(--bg); color: var(--text); font: inherit; }
#catalog { overflow: auto; padding: 0 6px 16px; }
.schema { margin-top: 6px; }
.schema > button { all: unset; cursor: pointer; display: flex; width: calc(100% - 12px); padding: 6px; font-weight: 600; font-size: 12px; letter-spacing: .04em; text-transform: uppercase; color: var(--muted); }
.schema > button::before { content: "\25BE"; width: 14px; display: inline-block; }
.schema.closed > button::before { content: "\25B8"; }
.schema.closed ul { display: none; }
.schema ul { list-style: none; margin: 0; padding: 0; }
.schema li button { all: unset; cursor: pointer; display: flex; justify-content: space-between; gap: 8px; width: calc(100% - 28px); padding: 4px 8px 4px 20px; border-radius: 5px; font-family: var(--mono); font-size: 12.5px; }
.schema li button:hover, .schema li button.active { background: var(--accent-soft); }
.schema li .name { min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.schema li .meta { flex-shrink: 0; color: var(--muted); font-family: var(--sans); font-size: 11.5px; white-space: nowrap; }
main { display: flex; flex-direction: column; min-width: 0; min-height: 0; padding: 14px 16px; gap: 10px; }
textarea { width: 100%; min-height: 96px; resize: vertical; padding: 10px 12px; border: 1px solid var(--line); border-radius: 8px; background: var(--panel); color: var(--text); font: 13px/1.5 var(--mono); }
textarea:focus, aside input:focus { outline: 2px solid var(--accent); outline-offset: -1px; }
.bar { display: flex; align-items: center; gap: 12px; flex-wrap: wrap; }
.bar button { background: var(--accent); color: var(--panel); border: 0; border-radius: 6px; padding: 7px 16px; font: 600 13px var(--sans); cursor: pointer; }
.bar button:disabled { opacity: .6; cursor: default; }
.hint, #status { color: var(--muted); font-size: 12.5px; }
.error { white-space: pre-wrap; background: var(--error-bg); color: var(--error); border-radius: 8px; padding: 10px 12px; font: 12.5px/1.5 var(--mono); }
.results { flex: 1; min-height: 0; overflow: auto; border: 1px solid var(--line); border-radius: 8px; background: var(--panel); }
table { border-collapse: collapse; font-size: 12.5px; min-width: 100%; }
th, td { padding: 5px 10px; border-bottom: 1px solid var(--line); text-align: left; white-space: nowrap; max-width: 420px; overflow: hidden; text-overflow: ellipsis; }
th { position: sticky; top: 0; background: var(--panel); box-shadow: inset 0 -1px var(--line); font-weight: 600; vertical-align: bottom; }
th .type { display: block; font-weight: 400; color: var(--muted); font-size: 11px; font-family: var(--mono); }
td { font-family: var(--mono); }
td.num { text-align: right; font-variant-numeric: tabular-nums; }
td.null { color: var(--muted); font-style: italic; }
tbody tr:hover td { background: var(--accent-soft); }
.empty { padding: 24px; color: var(--muted); }
@media (max-width: 720px) {
  .app { grid-template-columns: 1fr; grid-template-rows: 40vh 1fr; }
  aside { border-right: 0; border-bottom: 1px solid var(--line); }
}
</style>
</head>
<body>
<header><h1>Warehouse viewer</h1><span class="db" id="dbname"></span></header>
<div class="app">
  <aside>
    <input id="filter" type="search" placeholder="Filter tables" aria-label="Filter tables">
    <div id="catalog"></div>
  </aside>
  <main>
    <textarea id="sql" spellcheck="false" aria-label="SQL query">select * from gold.school_fundraising_leaderboard order by month desc, monthly_rank limit 100</textarea>
    <div class="bar">
      <button id="run">Run</button>
      <span class="hint">Ctrl+Enter runs the query (or just the selected text). Read-only.</span>
      <span id="status"></span>
    </div>
    <div id="message"></div>
    <div class="results" id="results"><div class="empty">Pick a table on the left or run a query.</div></div>
  </main>
</div>
<script>
const NUMERIC = /^(TINYINT|SMALLINT|INTEGER|BIGINT|HUGEINT|UTINYINT|USMALLINT|UINTEGER|UBIGINT|UHUGEINT|FLOAT|DOUBLE|DECIMAL|REAL)/i;
const $ = (id) => document.getElementById(id);
const el = (tag, cls, text) => { const e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; };
const fmtRows = (n) => n == null ? 'view' : n.toLocaleString() + (n === 1 ? ' row' : ' rows');
let activeButton = null;

function showError(text) { const m = $('message'); m.replaceChildren(); if (text) m.append(el('div', 'error', text)); }

async function loadCatalog() {
  const res = await fetch('/api/catalog'); const data = await res.json();
  if (data.error) { showError(data.error); return; }
  $('dbname').textContent = data.database;
  const box = $('catalog'); box.replaceChildren();
  for (const schema of data.schemas) {
    const wrap = el('div', 'schema' + (['bronze', 'meta'].includes(schema.name) ? ' closed' : ''));
    const head = el('button', null, `${schema.name} (${schema.tables.length})`);
    head.onclick = () => wrap.classList.toggle('closed');
    const list = el('ul');
    for (const t of schema.tables) {
      const li = el('li'); const b = el('button');
      b.dataset.name = `${schema.name}.${t.name}`;
      b.title = b.dataset.name;
      b.append(el('span', 'name', t.name), el('span', 'meta', t.kind === 'view' ? 'view' : fmtRows(t.rows)));
      b.onclick = () => { setActive(b); $('sql').value = `select * from ${schema.name}.${t.name} limit 100`; run(); };
      li.append(b); list.append(li);
    }
    wrap.append(head, list); box.append(wrap);
  }
  applyFilter();
}

function setActive(b) { if (activeButton) activeButton.classList.remove('active'); activeButton = b; b.classList.add('active'); }

function applyFilter() {
  const q = $('filter').value.trim().toLowerCase();
  for (const wrap of document.querySelectorAll('.schema')) {
    let shown = 0;
    for (const b of wrap.querySelectorAll('li button')) {
      const hit = !q || b.dataset.name.toLowerCase().includes(q);
      b.parentElement.style.display = hit ? '' : 'none'; shown += hit;
    }
    wrap.style.display = shown ? '' : 'none';
    if (q && shown) wrap.classList.remove('closed');
  }
}

async function run() {
  const box = $('sql');
  const selected = box.value.slice(box.selectionStart, box.selectionEnd).trim();
  const sql = selected || box.value;
  if (!sql.trim()) return;
  $('run').disabled = true; $('status').textContent = 'Running...'; showError('');
  try {
    const res = await fetch('/api/query', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ sql }) });
    const data = await res.json();
    if (data.error) { showError(data.error); $('status').textContent = ''; return; }
    render(data);
    const shown = data.rows.length.toLocaleString();
    $('status').textContent = data.truncated ? `First ${shown} rows shown (limit ${data.max_rows.toLocaleString()}) · ${data.elapsed_ms} ms`
                                             : `${shown} ${data.rows.length === 1 ? 'row' : 'rows'} · ${data.elapsed_ms} ms`;
  } catch (e) {
    showError('Could not reach the viewer. Is it still running in your terminal?');
    $('status').textContent = '';
  } finally { $('run').disabled = false; }
}

function render(data) {
  const box = $('results'); box.replaceChildren();
  if (!data.columns.length) { box.append(el('div', 'empty', 'The statement ran and returned no result set.')); return; }
  const table = el('table'); const head = el('tr');
  const numeric = data.columns.map((c) => NUMERIC.test(c.type));
  for (const c of data.columns) { const th = el('th', null, c.name); th.append(el('span', 'type', c.type)); head.append(th); }
  const thead = el('thead'); thead.append(head);
  const body = el('tbody');
  for (const row of data.rows) {
    const tr = el('tr');
    row.forEach((v, i) => {
      const td = v === null ? el('td', 'null', 'NULL') : el('td', numeric[i] ? 'num' : null, String(v));
      if (v !== null) td.title = String(v);
      tr.append(td);
    });
    body.append(tr);
  }
  table.append(thead, body);
  if (!data.rows.length) { box.append(table, el('div', 'empty', 'No rows.')); return; }
  box.append(table);
}

$('run').onclick = run;
$('sql').addEventListener('keydown', (e) => { if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') { e.preventDefault(); run(); } });
$('filter').addEventListener('input', applyFilter);
loadCatalog().then(run);
</script>
</body>
</html>
"""

if __name__ == '__main__':
    main()
