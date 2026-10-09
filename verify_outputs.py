#!/usr/bin/env python3
import json
import sys
from pathlib import Path

root = Path(__file__).resolve().parent
result = Path(sys.argv[1]) if len(sys.argv) > 1 else root / 'results'
data = root / 'data'
expected_dedup = sorted(set(' '.join(s.split()) for name in ('A.txt', 'B.txt')
                            for s in (data / name).read_text().splitlines() if s.strip()))
expected_numbers = sorted(int(s) for name in ('numbers1.txt', 'numbers2.txt', 'numbers3.txt')
                          for s in (data / name).read_text().splitlines() if s.strip())
edges = [tuple(s.split()) for s in (data / 'family.txt').read_text().splitlines()[1:] if s.strip()]
expected_family = sorted(set((child, grandparent) for child, parent in edges
                            for middle, grandparent in edges if parent == middle))
checks = {}
for name, expected in (
    ('dedup', expected_dedup),
    ('sort', [(i, n) for i, n in enumerate(expected_numbers, 1)]),
    ('family', expected_family),
):
    path = result / (name + '.txt')
    if not path.exists():
        checks[name] = {'passed': False, 'reason': 'missing actual output'}
        continue
    rows = [s for s in path.read_text().splitlines() if s.strip()]
    actual = [' '.join(s.split()) for s in rows] if name == 'dedup' else (
        [tuple(map(int, s.split())) for s in rows] if name == 'sort' else sorted(tuple(s.split()) for s in rows))
    checks[name] = {'passed': actual == expected, 'actual_rows': len(actual),
                    'expected_rows': len(expected), 'expected': expected, 'actual': actual}
print(json.dumps(checks, ensure_ascii=False, indent=2))
sys.exit(0 if all(c['passed'] for c in checks.values()) else 1)
