#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path
import yaml

path = Path("/home/alex/projects/ofm-microservices/ofm-docs/asyncapi/nats-asyncapi.yaml")
yaml.safe_load(path.read_text())
print("AsyncAPI YAML is valid")
PY
