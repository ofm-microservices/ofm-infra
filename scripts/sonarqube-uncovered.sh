#!/usr/bin/env zsh

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <repo-dir> <project-key>" >&2
  exit 1
fi

repo_dir="$1"
project_key="$2"

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
  local response api_errors matches rel_path uncovered_count hits_data abs_path line_no hit_count code_line

  if ! response="$(
    curl -sS -u "${token}:" \
      "${sonar_url}/api/measures/component_tree?component=${project_key}&metricKeys=uncovered_lines,coverage_line_hits_data&qualifiers=FIL&ps=500"
  )"; then
    return 1
  fi

  api_errors="$(printf '%s' "${response}" | jq -r '.errors[]?.msg')"
  if [[ -n "${api_errors}" ]]; then
    return 1
  fi

  matches="$(
    printf '%s' "${response}" | jq -r '
      .components[]
      | {
          path: (.path // ((.key | split(":"))[1:] | join(":"))),
          uncovered: ((.measures[]? | select(.metric == "uncovered_lines") | .value) // "0"),
          hits: ((.measures[]? | select(.metric == "coverage_line_hits_data") | .value) // "")
        }
      | select((.uncovered | tonumber) > 0)
      | [.path, .uncovered, .hits]
      | @tsv
    '
  )"

  if [[ -z "${matches}" ]]; then
    echo "No files with uncovered lines were reported by SonarQube for ${project_key}."
    return 0
  fi

  while IFS=$'\t' read -r rel_path uncovered_count hits_data; do
    [[ -z "${rel_path}" ]] && continue

    abs_path="${repo_path}/${rel_path}"
    if [[ ! -f "${abs_path}" ]]; then
      echo "FILE: ${rel_path} (${uncovered_count} uncovered, local file not found)"
      echo
      continue
    fi

    zero_hit_lines=()
    if [[ -n "${hits_data}" ]]; then
      for pair in ${(s/;/)hits_data}; do
        [[ -z "${pair}" ]] && continue
        line_no="${pair%%=*}"
        hit_count="${pair#*=}"
        if [[ "${hit_count}" == "0" ]]; then
          zero_hit_lines+=("${line_no}")
        fi
      done
    fi

    echo "FILE: ${rel_path} (${uncovered_count} uncovered)"
    if (( ${#zero_hit_lines[@]} == 0 )); then
      echo "  SonarQube did not expose per-line zero-hit data for this file."
      echo
      continue
    fi

    for line_no in ${(on)zero_hit_lines}; do
      code_line="$(awk -v target="${line_no}" 'NR == target {print; exit}' "${abs_path}")"
      printf '  %s | %s\n' "${line_no}" "${code_line}"
    done
    echo
  done <<< "${matches}"

  return 0
}

print_from_coverage() {
  local coverage_path
  coverage_path="${repo_path}/coverage.out"

  if [[ ! -f "${coverage_path}" ]]; then
    echo "SonarQube API access failed and coverage file not found: ${coverage_path}" >&2
    exit 1
  fi

  COVERAGE_PATH="${coverage_path}" REPO_PATH="${repo_path}" python3 <<'PY'
import os
from collections import defaultdict

coverage_path = os.environ["COVERAGE_PATH"]
repo_path = os.environ["REPO_PATH"]

files = defaultdict(set)

with open(coverage_path, "r", encoding="utf-8") as f:
    for raw in f:
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

if not files:
    print("No uncovered lines were found in coverage.out.")
    raise SystemExit(0)

for rel_path in sorted(files):
    normalized_path = rel_path
    repo_name = os.path.basename(repo_path)
    module_prefix = repo_name.replace("ofm-", "", 1) + "/"
    if normalized_path.startswith(module_prefix):
        normalized_path = normalized_path[len(module_prefix):]

    abs_path = os.path.join(repo_path, normalized_path)
    if not os.path.isfile(abs_path):
        print(f"FILE: {rel_path} ({len(files[rel_path])} uncovered, local file not found)")
        print()
        continue
    with open(abs_path, "r", encoding="utf-8") as src:
        source_lines = src.read().splitlines()
    print(f"FILE: {normalized_path} ({len(files[rel_path])} uncovered)")
    for line_no in sorted(files[rel_path]):
        code = source_lines[line_no - 1] if line_no - 1 < len(source_lines) else ""
        print(f"  {line_no} | {code}")
    print()
PY
}

if ! print_from_api; then
  print_from_coverage
fi
