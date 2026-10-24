#!/usr/bin/env python3
"""List files by duplicated lines for a SonarQube project.
Usage: python sonar_duplications.py --project threeduo-backend --token <TOKEN> [--host http://localhost:9000] > dups.txt
"""
import argparse
import requests

p = argparse.ArgumentParser()
p.add_argument("--host", default="http://localhost:9000")
p.add_argument("--project", required=True)
p.add_argument("--token", required=True)
p.add_argument("--file", help="e.g. routes/games.js: print the duplicated line ranges of that file")
a = p.parse_args()

if a.file:
    r = requests.get(f"{a.host}/api/duplications/show", params={"key": f"{a.project}:{a.file}"},
                     auth=(a.token, ""), timeout=30)
    r.raise_for_status()
    data = r.json()
    files = {k: v["name"] for k, v in data.get("files", {}).items()}
    for d in data.get("duplications", []):
        parts = [f'{files[b["_ref"]]}:{b["from"]}-{b["from"] + b["size"] - 1}' for b in d["blocks"]]
        print("  <->  ".join(parts))
    raise SystemExit(0)

r = requests.get(
    f"{a.host}/api/measures/component_tree",
    params={"component": a.project, "qualifiers": "FIL,UTS",
            "metricKeys": "duplicated_lines,duplicated_blocks,ncloc",
            "metricSort": "duplicated_lines", "metricSortFilter": "withMeasuresOnly",
            "s": "metric", "asc": "false", "ps": 100},
    auth=(a.token, ""), timeout=30)
r.raise_for_status()
for c in r.json()["components"]:
    m = {x["metric"]: x.get("value", "0") for x in c["measures"]}
    print(f'{c["path"]} | duplicated_lines={m.get("duplicated_lines", "0")} '
          f'blocks={m.get("duplicated_blocks", "0")} ncloc={m.get("ncloc", "?")}')
