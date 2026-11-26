"""Mark Vanguard backlog tasks (docs/vanguard/vanguard_backlog.json).

python tools/vg_status.py <status> <evidence> <id> [<id> ...]
An id like VG02-* marks every task of that phase except the gate.
"""
import json
import sys

PATH = 'docs/vanguard/vanguard_backlog.json'


def main():
    status, evidence, ids = sys.argv[1], sys.argv[2], sys.argv[3:]
    data = json.load(open(PATH, encoding='utf-8'))
    hit = []
    for t in data['tasks']:
        for want in ids:
            if (want.endswith('*') and t['id'].startswith(want[:-1]) and not t['id'].endswith('GATE')) or t['id'] == want:
                t['status'] = status
                t['evidence'] = evidence
                t['updated'] = '2026-11-26'
                hit.append(t['id'])
    open(PATH, 'w', encoding='utf-8').write(json.dumps(data, indent=2, ensure_ascii=False) + '\n')
    print('marked', ', '.join(hit) or 'nothing')


if __name__ == '__main__':
    main()
