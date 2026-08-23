#!/usr/bin/env python3
"""Compare normalized user snapshots without modifying either database."""
import csv
import sys

FIELDS = ("user_id", "username", "first_name", "last_name")

def load(path):
    with open(path, newline="", encoding="utf-8") as source:
        rows = {}
        for row in csv.DictReader(source):
            missing = [field for field in FIELDS if field not in row]
            if missing:
                raise SystemExit(f"{path}: missing columns: {', '.join(missing)}")
            key = row["user_id"]
            rows[key] = tuple(row[field] for field in FIELDS[1:])
        return rows

def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: reconcile_users.py MONOLITH_CSV SERVICE_CSV")
    legacy = load(sys.argv[1])
    service = load(sys.argv[2])
    mismatches = []
    for user_id in sorted(set(legacy) | set(service)):
        if user_id not in service:
            mismatches.append(("missing_in_service", user_id))
        elif user_id not in legacy:
            mismatches.append(("missing_in_monolith", user_id))
        elif legacy[user_id] != service[user_id]:
            mismatches.append(("different_profile", user_id))
    for kind, user_id in mismatches:
        print(f"{kind}\t{user_id}")
    return 1 if mismatches else 0

if __name__ == "__main__":
    sys.exit(main())
