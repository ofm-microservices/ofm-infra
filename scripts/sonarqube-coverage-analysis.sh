#!/usr/bin/env zsh

set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "usage: $0 <repo-dir> <project-key> [--all]" >&2
  exit 1
fi

repo_dir="$1"
project_key="$2"
show_all_lines="0"

if [[ $# -eq 3 ]]; then
  if [[ "$3" != "--all" ]]; then
    echo "unknown option: $3" >&2
    echo "usage: $0 <repo-dir> <project-key> [--all]" >&2
    exit 1
  fi
  show_all_lines="1"
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"
root_dir="$(cd "${script_dir}/../.." && pwd)"
repo_path="${root_dir}/${repo_dir}"

if [[ ! -d "${repo_path}" ]]; then
  echo "repo path not found: ${repo_path}" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

sonar_url="${SONARQUBE_BROWSER_URL:-${SONARQUBE_URL:-http://localhost:9005}}"
token="${SONAR_TOKEN:-}"

if [[ -z "${token}" ]]; then
  echo "SONAR_TOKEN is required" >&2
  exit 1
fi

print_from_api() {
  local response api_errors branch_line_coverage line_coverage uncovered_lines line_hits_data

  if ! response="$(
    curl -sS -u "${token}:" \
      "${sonar_url}/api/measures/component_tree?component=${project_key}&metricKeys=coverage,line_coverage,branch_coverage,uncovered_lines,lines_to_cover,coverage_line_hits_data&qualifiers=FIL&ps=500"
  )"; then
    return 1
  fi

  api_errors="$(printf '%s' "${response}" | jq -r '.errors[]?.msg')"
  if [[ -n "${api_errors}" ]]; then
    return 1
  fi

  SONAR_RESPONSE="${response}" REPO_PATH="${repo_path}" SHOW_ALL_LINES="${show_all_lines}" python3 <<'PY'
import json
import os
from pathlib import Path

response = json.loads(os.environ["SONAR_RESPONSE"])
repo_path = Path(os.environ["REPO_PATH"])
show_all_lines = os.environ.get("SHOW_ALL_LINES") == "1"

components = []
for component in response.get("components", []):
    measures = {m["metric"]: m.get("value", "") for m in component.get("measures", [])}
    uncovered = int(float(measures.get("uncovered_lines", "0") or "0"))
    lines_to_cover = int(float(measures.get("lines_to_cover", "0") or "0"))
    coverage = float(measures.get("coverage", "0") or "0")
    line_coverage = float(measures.get("line_coverage", "0") or "0")
    branch_coverage = float(measures.get("branch_coverage", "0") or "0")
    hits_data = measures.get("coverage_line_hits_data", "") or ""
    path = component.get("path") or ":".join(component.get("key", "").split(":")[1:])
    components.append(
        {
            "path": path,
            "uncovered": uncovered,
            "lines_to_cover": lines_to_cover,
            "coverage": coverage,
            "line_coverage": line_coverage,
            "branch_coverage": branch_coverage,
            "hits_data": hits_data,
        }
    )

components.sort(key=lambda item: (-item["uncovered"], item["coverage"], item["path"]))

if not components:
    print(f"No SonarQube coverage data found for {repo_path.name}.")
    raise SystemExit(0)

total_lines_to_cover = sum(item["lines_to_cover"] for item in components)
total_uncovered = sum(item["uncovered"] for item in components)
overall_line_coverage = 0.0
if total_lines_to_cover > 0:
    overall_line_coverage = ((total_lines_to_cover - total_uncovered) / total_lines_to_cover) * 100

print(f"Project: {repo_path.name}")
print(f"Files with coverage data: {len(components)}")
print(f"Lines to cover: {total_lines_to_cover}")
print(f"Uncovered lines: {total_uncovered}")
print(f"Approx line coverage from Sonar file metrics: {overall_line_coverage:.1f}%")
print()

priority = [item for item in components if item["uncovered"] > 0][:15]
if not priority:
    print("No uncovered files were reported by SonarQube.")
    raise SystemExit(0)

print("Priority files:")
for index, item in enumerate(priority, start=1):
    print(
        f"{index}. {item['path']} | uncovered={item['uncovered']} | "
        f"coverage={item['coverage']:.1f}% | line={item['line_coverage']:.1f}% | branch={item['branch_coverage']:.1f}%"
    )

print()
print("What to cover next:")
for item in priority:
    path = repo_path / item["path"]
    zero_hit_lines = []
    if item["hits_data"]:
        for pair in item["hits_data"].split(";"):
            if not pair:
                continue
            line_no, hit_count = pair.split("=", 1)
            if hit_count == "0":
                zero_hit_lines.append(int(line_no))

    print(f"- {item['path']}")
    print(
        f"  Focus: {item['uncovered']} uncovered line(s), "
        f"{item['lines_to_cover']} line(s) to cover, Sonar coverage {item['coverage']:.1f}%."
    )

    if not path.is_file():
        print("  Local file missing; inspect the Sonar project path mapping.")
        continue

    source_lines = path.read_text(encoding="utf-8").splitlines()
    if not zero_hit_lines:
        print("  Sonar did not expose zero-hit line data for this file.")
        continue

    lines_to_print = zero_hit_lines if show_all_lines else zero_hit_lines[:8]
    if show_all_lines:
        print("  Uncovered lines:")
    else:
        print("  First uncovered lines:")
    for line_no in lines_to_print:
        code = source_lines[line_no - 1] if line_no - 1 < len(source_lines) else ""
        print(f"    {line_no}: {code}")
    if not show_all_lines and len(zero_hit_lines) > len(lines_to_print):
        print(f"    ... and {len(zero_hit_lines) - len(lines_to_print)} more uncovered line(s)")
PY

  return 0
}

print_from_coverage() {
  local coverage_path
  coverage_path="${repo_path}/coverage.out"

  if [[ ! -f "${coverage_path}" ]]; then
    echo "SonarQube API access failed and coverage file not found: ${coverage_path}" >&2
    exit 1
  fi

  COVERAGE_PATH="${coverage_path}" REPO_PATH="${repo_path}" SHOW_ALL_LINES="${show_all_lines}" python3 <<'PY'
import os
from collections import defaultdict
from pathlib import Path

coverage_path = Path(os.environ["COVERAGE_PATH"])
repo_path = Path(os.environ["REPO_PATH"])
show_all_lines = os.environ.get("SHOW_ALL_LINES") == "1"

files = defaultdict(set)

with coverage_path.open("r", encoding="utf-8") as handle:
    for raw in handle:
        line = raw.strip()
        if not line or line.startswith("mode:"):
            continue
        path_and_range, _num_stmts, count = line.split()
        if count != "0":
            continue
        rel_path, line_range = path_and_range.split(":", 1)
        start, end = line_range.split(",", 1)
        start_line = int(start.split(".", 1)[0])
        end_line = int(end.split(".", 1)[0])
        for line_no in range(start_line, end_line + 1):
            files[rel_path].add(line_no)

normalized = []
module_prefix = repo_path.name.replace("ofm-", "", 1) + "/"
for rel_path, lines in files.items():
    normalized_path = rel_path[len(module_prefix):] if rel_path.startswith(module_prefix) else rel_path
    normalized.append((normalized_path, sorted(lines)))

normalized.sort(key=lambda item: (-len(item[1]), item[0]))

print(f"Project: {repo_path.name}")
print(f"Files with uncovered lines: {len(normalized)}")
print(f"Total uncovered lines from coverage.out: {sum(len(lines) for _, lines in normalized)}")
print()

print("Priority files:")
for index, (rel_path, lines) in enumerate(normalized[:15], start=1):
    print(f"{index}. {rel_path} | uncovered={len(lines)}")

print()
print("What to cover next:")
for rel_path, lines in normalized[:15]:
    abs_path = repo_path / rel_path
    print(f"- {rel_path}")
    print(f"  Focus: {len(lines)} uncovered line(s) from coverage.out.")
    if not abs_path.is_file():
      print("  Local file missing; inspect module path mapping.")
      continue
    source_lines = abs_path.read_text(encoding="utf-8").splitlines()
    lines_to_print = lines if show_all_lines else lines[:8]
    if show_all_lines:
      print("  Uncovered lines:")
    else:
      print("  First uncovered lines:")
    for line_no in lines_to_print:
      code = source_lines[line_no - 1] if line_no - 1 < len(source_lines) else ""
      print(f"    {line_no}: {code}")
    if not show_all_lines and len(lines) > len(lines_to_print):
      print(f"    ... and {len(lines) - len(lines_to_print)} more uncovered line(s)")
PY
}

if ! print_from_api; then
  print_from_coverage
fi
