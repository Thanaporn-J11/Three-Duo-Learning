#!/usr/bin/env python3
"""Dump every open issue of a SonarQube project as plain text: file:line, severity, rule, message.
Usage: python sonar_issues.py --project threeduo-backend --token <TOKEN> [--host http://localhost:9000] > issues.txt
"""
import argparse
import requests

p = argparse.ArgumentParser()
p.add_argument("--host", default="http://localhost:9000")
p.add_argument("--project", required=True)
p.add_argument("--token", required=True)
a = p.parse_args()

page, rows = 1, []
while True:
    r = requests.get(
        f"{a.host}/api/issues/search",
        params={"componentKeys": a.project, "issueStatuses": "OPEN,CONFIRMED", "ps": 500, "p": page},
        auth=(a.token, ""), timeout=30)
    r.raise_for_status()
    data = r.json()
    rows += data["issues"]
    if page * 500 >= data["paging"]["total"]:
        break
    page += 1

rows.sort(key=lambda i: (i["component"], i.get("line", 0)))
for i in rows:
    comp = i["component"].split(":", 1)[-1]
    print(f'{comp}:{i.get("line", "?")} | {i["severity"]} | {i["rule"]} | {i["message"]}')
print(f"TOTAL {len(rows)}")
