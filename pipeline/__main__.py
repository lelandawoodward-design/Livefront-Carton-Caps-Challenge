"""
Command line for the Carton Caps pipeline.

    python -m pipeline run                 # generate -> feed -> ingest -> dbt build -> export
    python -m pipeline demo-incremental    # batch-by-batch build checked against a full rebuild
    python -m pipeline report              # run analysis/sample_queries.sql

Individual steps: generate, feed, ingest, transform, export.
Files go under the repo root, or under $CARTON_CAPS_HOME if set.
"""

import argparse
import sys

from . import export, feed, ingest, report, steps, transform
from .config import default_paths


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(prog='python -m pipeline', description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='command', required=True)

    p = sub.add_parser('run', help='full pipeline from a clean warehouse')
    p.add_argument('--cadence', choices=['monthly', 'single'], default='monthly',
                   help='landing batches: one per month (default) or a single batch')
    p.add_argument('--scale', type=float, default=1.0,
                   help='multiply users, purchases and referrals (e.g. 10 or 100)')
    p.add_argument('--reuse-data', action='store_true', help="don't regenerate data/ if it exists")

    p = sub.add_parser('generate', help='run data_generator.py into data/')
    p.add_argument('--scale', type=float, default=1.0)

    p = sub.add_parser('feed', help='split data/ into dated landing batches')
    p.add_argument('--cadence', choices=['monthly', 'single'], default='monthly')

    p = sub.add_parser('ingest', help='load new landing batches into bronze')
    p.add_argument('--upto', help='stop after this batch id (YYYY-MM-DD)')

    p = sub.add_parser('transform', help='dbt build (models and tests)')
    p.add_argument('--full-refresh', action='store_true', help='rebuild incremental models from bronze')
    p.add_argument('--select', nargs='+', help='dbt node selection')

    sub.add_parser('export', help='write gold and quality tables to exports/*.parquet')
    sub.add_parser('report', help='run the sample queries and print the results')

    p = sub.add_parser('demo-incremental', help='build batch by batch and compare with a full rebuild')
    p.add_argument('--split-after', help='last batch of the first build (default: 3/4 of the way through)')

    args = parser.parse_args(argv)
    paths = default_paths()

    if args.command == 'run':
        steps.run_all(paths, cadence=args.cadence, scale=args.scale, regenerate=not args.reuse_data)
        print('\nNext: python -m pipeline report')
    elif args.command == 'generate':
        steps.generate(paths, args.scale)
    elif args.command == 'feed':
        batches = feed.build_batches(paths.data, paths.landing, args.cadence)
        print(f'{len(batches)} batches written to {paths.landing}')
    elif args.command == 'ingest':
        summary = ingest.ingest(paths, upto=args.upto)
        print(f"loaded batches: {summary['batches'] or 'none new'}; rows: {summary['rows']}")
    elif args.command == 'transform':
        transform.run_dbt(paths, 'build', full_refresh=args.full_refresh, select=args.select)
    elif args.command == 'export':
        for path in export.export_tables(paths):
            print(path)
    elif args.command == 'report':
        print(report.run_report(paths))
    elif args.command == 'demo-incremental':
        return 0 if steps.demo_incremental(paths, args.split_after) else 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
