#!/usr/bin/env zsh

set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 <repo-dir> <project-key> <project-name>" >&2
  exit 1
fi

repo_dir="$1"
project_key="$2"
project_name="$3"

script_dir="$(cd "$(dirname "$0")" && pwd)"
root_dir="$(cd "${script_dir}/../.." && pwd)"
repo_path="${root_dir}/${repo_dir}"

if [[ ! -d "${repo_path}" ]]; then
  echo "repo path not found: ${repo_path}" >&2
  exit 1
fi

network_name="${SONARQUBE_DOCKER_NETWORK:-ofm-infra_default}"
host_url="${SONARQUBE_URL:-http://sonarqube:9000}"
token="${SONAR_TOKEN:-}"

if [[ -z "${token}" ]]; then
  echo "SONAR_TOKEN is required" >&2
  exit 1
fi

cd "${repo_path}"
GOCACHE=/tmp/gocache go test -p 1 ./... -covermode=atomic -coverpkg=./... -coverprofile=coverage.out
GOCACHE=/tmp/gocache go tool cover -func=coverage.out | tail -n 1

docker run --rm \
  --network "${network_name}" \
  -e SONAR_HOST_URL="${host_url}" \
  -e SONAR_TOKEN="${token}" \
  -v "${root_dir}:/workspace" \
  -v "${HOME}/.sonar/cache:/opt/sonar-scanner/.sonar/cache" \
  sonarsource/sonar-scanner-cli:latest \
  sonar-scanner \
    -Dsonar.projectKey="${project_key}" \
    -Dsonar.projectName="${project_name}" \
    -Dsonar.projectVersion="local" \
    -Dsonar.projectBaseDir="/workspace/${repo_dir}" \
    -Dsonar.token="${token}" \
    -Dsonar.sources=. \
    -Dsonar.tests=. \
    -Dsonar.test.inclusions="**/*_test.go" \
    -Dsonar.exclusions="**/*_test.go,**/*.pb.go,**/*_grpc.pb.go,coverage.out" \
    -Dsonar.go.coverage.reportPaths="coverage.out"
