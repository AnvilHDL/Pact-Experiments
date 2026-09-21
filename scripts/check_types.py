#!/usr/bin/env python3
"""Check all PACT benchmark sources without running compatibility games."""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--jobs', type=int, default=4)
    args = parser.parse_args()
    if args.jobs < 1:
        parser.error('--jobs must be positive')
    compiler_dir = Path(os.environ.get('PACT_DIR', ROOT.parent / 'Pact')).resolve()
    subprocess.run(['dune', 'build', '--root', str(compiler_dir), 'bin/main.exe'], check=True)
    output = ROOT / 'logs/typecheck' / datetime.now().strftime('%Y%m%d_%H%M%S_%f')
    output.mkdir(parents=True)
    compiler = output / 'pact'
    shutil.copy2(compiler_dir / '_build/default/bin/main.exe', compiler)
    source_dir = ROOT / 'src/compat'

    def check(source):
        relative = source.relative_to(source_dir)
        log = output / relative.with_suffix('.log')
        log.parent.mkdir(parents=True, exist_ok=True)
        started = time.monotonic()
        with log.open('w') as stream:
            result = subprocess.run([str(compiler), '-disable-lt-checks',
                                     '-disable-compat-checks', '-just-check', str(source)],
                                    cwd=output, stdout=stream, stderr=subprocess.STDOUT)
        return {'file': str(relative), 'returncode': result.returncode,
                'elapsed_seconds': round(time.monotonic() - started, 3)}

    results = []
    print(f'Logs: {output}', flush=True)
    with ThreadPoolExecutor(max_workers=args.jobs) as executor:
        pending = [executor.submit(check, source) for source in sorted(source_dir.rglob('*.anvil'))]
        for future in as_completed(pending):
            row = future.result()
            results.append(row)
            print(f"{'PASS' if row['returncode'] == 0 else 'FAIL'} {row['file']}", flush=True)
            (output / 'results.json').write_text(json.dumps(sorted(results, key=lambda r: r['file']), indent=2) + '\n')
    failed = sum(row['returncode'] != 0 for row in results)
    print(f'{len(results) - failed} passed; {failed} failed.')
    return int(failed != 0)


if __name__ == '__main__':
    sys.exit(main())
