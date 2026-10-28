"""
Simulate how data would arrive from production.

The generator writes one full extract per entity. This step splits those
extracts into dated landing batches, one folder per cutoff:

    landing/batch=YYYY-MM-DD/<entity>.csv

* schools, users, products, districts: a full snapshot of every row that existed
  at the cutoff (districts, reference data with no timestamp, is in every batch).
* purchases: rows purchased since the previous cutoff (append-only events).
* referrals: rows that are new, or whose state changed, since the previous
  cutoff (change data). An invite that converts after a cutoff is emitted as
  'clicked' first, then again as 'converted' in the batch where it converts.

Rows with an unparseable timestamp go into the first batch, so the
data-quality layer sees them rather than this step silently dropping them.
"""

import csv
import shutil
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional

from .config import CONTRACTS, SNAPSHOT_ENTITIES

TIME_COLUMN = {'schools': 'created_at', 'users': 'created_at', 'products': 'created_at',
               'purchases': 'purchased_at', 'referrals': 'sent_at'}


def _ts(value: str) -> Optional[datetime]:
    try:
        return datetime.fromisoformat(value) if value else None
    except ValueError:
        return None


def _read(path: Path) -> List[Dict[str, str]]:
    with open(path, newline='', encoding='utf-8') as f:
        return list(csv.DictReader(f))


def _write(path: Path, entity: str, rows: List[Dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=CONTRACTS[entity], extrasaction='ignore')
        writer.writeheader()
        writer.writerows(rows)


def month_end_cutoffs(first: date, last: date) -> List[date]:
    """Last day of every month from first's month through last's month."""
    cutoffs, year, month = [], first.year, first.month
    while (year, month) <= (last.year, last.month):
        next_month = date(year + (month == 12), month % 12 + 1, 1)
        cutoffs.append(next_month - timedelta(days=1))
        year, month = next_month.year, next_month.month
    return cutoffs


def _referral_as_of(row: Dict[str, str], cutoff_end: datetime) -> Dict[str, str]:
    """The state a referral had at the cutoff: not yet converted if it converts later."""
    converted = _ts(row['converted_at'])
    if row['status'] == 'converted' and converted is not None and converted >= cutoff_end:
        return dict(row, status='clicked', referred_user_id='', converted_at='')
    return row


def build_batches(data_dir: Path, landing_dir: Path, cadence: str = 'monthly') -> List[str]:
    """Write landing batches from the generator's CSVs. Returns the batch ids written."""
    if cadence not in ('monthly', 'single'):
        raise ValueError("cadence must be 'monthly' or 'single'")
    extracts = {entity: _read(data_dir / f'{entity}.csv') for entity in CONTRACTS}

    event_times = [_ts(r[TIME_COLUMN[e]]) for e in ('users', 'purchases', 'referrals') for r in extracts[e]]
    event_times = [t for t in event_times if t is not None]
    first, last = min(event_times).date(), max(event_times).date()
    cutoffs = month_end_cutoffs(first, last) if cadence == 'monthly' else [last]

    if landing_dir.exists():
        shutil.rmtree(landing_dir)

    emitted_referrals: Dict[int, Dict[str, str]] = {}
    previous_end: Optional[datetime] = None
    batch_ids = []
    for cutoff in cutoffs:
        end = datetime.combine(cutoff + timedelta(days=1), datetime.min.time())  # exclusive
        batch_dir = landing_dir / f'batch={cutoff.isoformat()}'

        def visible(row, entity):
            if entity not in TIME_COLUMN:  # reference data with no timestamp: always present
                return True
            t = _ts(row[TIME_COLUMN[entity]])
            return t is None or t < end

        for entity in SNAPSHOT_ENTITIES:
            _write(batch_dir / f'{entity}.csv', entity, [r for r in extracts[entity] if visible(r, entity)])

        purchases = []
        for r in extracts['purchases']:
            t = _ts(r['purchased_at'])
            if t is None:
                if previous_end is None:
                    purchases.append(r)
            elif t < end and (previous_end is None or t >= previous_end):
                purchases.append(r)
        _write(batch_dir / 'purchases.csv', 'purchases', purchases)

        referrals = []
        for i, r in enumerate(extracts['referrals']):
            if not visible(r, 'referrals'):
                continue
            state = _referral_as_of(r, end)
            if emitted_referrals.get(i) != state:
                emitted_referrals[i] = state
                referrals.append(state)
        _write(batch_dir / 'referrals.csv', 'referrals', referrals)

        batch_ids.append(cutoff.isoformat())
        previous_end = end
    return batch_ids
