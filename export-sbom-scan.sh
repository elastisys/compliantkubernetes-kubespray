#!/usr/bin/env bash
set -euo pipefail

# This script enumerates every provider scenario under config/*,
# merges the corresponding group vars with the shared common vars,
# runs the Kubespray playbook helpers to resolve image variables,
# and emits per-scenario plus global image inventories for SBOM/CVE work.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CKKS_ROOT="$SCRIPT_DIR"
KUBESPRAY_DIR="$CKKS_ROOT/kubespray"
OUTPUT_ROOT="$CKKS_ROOT/tmp/sbom"

DEFAULT_INVENTORY="$KUBESPRAY_DIR/inventory/sample/inventory.ini"
INVENTORY_FILE="${CKKS_INVENTORY:-$DEFAULT_INVENTORY}"
ANSIBLE_CFG="${CKKS_ANSIBLE_CFG:-$CKKS_ROOT/playbooks/ansible.cfg}"

if [[ ! -d "$KUBESPRAY_DIR" ]]; then
  echo "Kubespray submodule not found at $KUBESPRAY_DIR" >&2
  exit 1
fi

if [[ ! -f "$INVENTORY_FILE" ]]; then
  echo "Inventory file not found: $INVENTORY_FILE" >&2
  exit 1
fi

if [[ ! -f "$ANSIBLE_CFG" ]]; then
  echo "Ansible config not found: $ANSIBLE_CFG" >&2
  exit 1
fi

mkdir -p "$OUTPUT_ROOT"

abspath() {
  python3 - <<'PY' "$1"
import os, sys
print(os.path.realpath(sys.argv[1]))
PY
}

collect_group_var_files() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0
  while IFS= read -r -d '' file; do
    GROUP_VAR_FILES+=("$(abspath "$file")")
  done < <(find "$dir" -type f \( -name '*.yml' -o -name '*.yaml' \) -print0)
}

# Shared common group vars (used for every scenario).
COMMON_GROUP_VARS=()
GROUP_VAR_FILES=()
collect_group_var_files "$CKKS_ROOT/config/common/group_vars"
COMMON_GROUP_VARS=("${GROUP_VAR_FILES[@]}")
GROUP_VAR_FILES=()

# Discover scenario directories (anything under config/* that contains group_vars).
readarray -t SCENARIOS < <(
  find "$CKKS_ROOT/config" -mindepth 1 -maxdepth 1 -type d \
    -not -name '.state' -not -name '.terraform' -print | sort
)

SCENARIO_NAMES=()
for scenario_path in "${SCENARIOS[@]}"; do
  if [[ -d "$scenario_path/group_vars" ]]; then
    SCENARIO_NAMES+=("$(basename "$scenario_path")")
  fi
done

if ((${#SCENARIO_NAMES[@]} == 0)); then
  echo "No scenario directories with group_vars found under config/" >&2
  exit 1
fi

REPORT_FILES=()

for scenario in "${SCENARIO_NAMES[@]}"; do
  echo "=== Processing scenario: $scenario ==="

  scenario_output="$OUTPUT_ROOT/$scenario"
  mkdir -p "$scenario_output"

  playbook_file="$scenario_output/dump-image-vars.yml"
  inventory_json="$scenario_output/kubespray-inventory.json"
  images_json="$scenario_output/kubespray-image-vars.json"
  static_json="$scenario_output/kubespray-static-images.json"
  report_json="$scenario_output/kubespray-images-report.json"

  cat > "$playbook_file" <<'PLAYBOOK'
---
- hosts: all
  gather_facts: false
  tasks:
    - name: Load Kubespray download defaults
      run_once: true
      include_vars:
        file: "{{ download_defaults_file }}"

    - name: Collect Kubespray image variables across hostvars
      run_once: true
      delegate_to: localhost
      set_fact:
        kubespray_image_vars: >-
          {{
            vars
            | dict2items
            | selectattr('key', 'search', 'image')
            | items2dict
          }}

    - name: Emit image variables
      run_once: true
      delegate_to: localhost
      debug:
        var: kubespray_image_vars
PLAYBOOK

  extra_vars_args=(--extra-vars "download_defaults_file=$(abspath "$KUBESPRAY_DIR/roles/kubespray-defaults/defaults/main/download.yml")")

  for file in "${COMMON_GROUP_VARS[@]}"; do
    extra_vars_args+=(--extra-vars "@$file")
  done

  scenario_group_var_dir="$CKKS_ROOT/config/$scenario/group_vars"
  if [[ "$scenario" != "common" && -d "$scenario_group_var_dir" ]]; then
    GROUP_VAR_FILES=()
    collect_group_var_files "$scenario_group_var_dir"
    for file in "${GROUP_VAR_FILES[@]}"; do
      extra_vars_args+=(--extra-vars "@$file")
    done
    GROUP_VAR_FILES=()
  fi

  pushd "$KUBESPRAY_DIR" >/dev/null

  ANSIBLE_CONFIG="$ANSIBLE_CFG" ANSIBLE_STDOUT_CALLBACK=json \
    ansible-inventory -i "$INVENTORY_FILE" --list --export --vars \
      "${extra_vars_args[@]}" > "$inventory_json"

  ANSIBLE_CONFIG="$ANSIBLE_CFG" ANSIBLE_STDOUT_CALLBACK=json \
    ansible-playbook -i "$INVENTORY_FILE" "$playbook_file" \
      "${extra_vars_args[@]}" > "$images_json"

  popd >/dev/null

  python3 - "$KUBESPRAY_DIR" "$scenario" "$images_json" "$static_json" "$report_json" "$INVENTORY_FILE" <<'PY'
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

kubespray_dir = Path(sys.argv[1]).resolve()
scenario_name = sys.argv[2]
ansible_json_path = Path(sys.argv[3]).resolve()
static_json_path = Path(sys.argv[4]).resolve()
report_json_path = Path(sys.argv[5]).resolve()
inventory_path = Path(sys.argv[6]).resolve()

def load_ansible_image_vars(path: Path) -> dict:
    if not path.exists():
        return {}
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError:
        return {}

    merged = {}
    for play in data.get("plays", []):
        for task in play.get("tasks", []):
            for host_data in task.get("hosts", {}).values():
                for key in ("ansible_facts", "kubespray_image_vars"):
                    payload = host_data.get(key, {})
                    if isinstance(payload, dict):
                        for var_key, var_value in payload.items():
                            merged.setdefault(var_key, var_value)
    filtered = {}
    for key, value in merged.items():
        lower_key = key.lower()
        if "image" not in lower_key:
            continue
        if any(token in lower_key for token in ("imagepull", "image_pull_policy", "image_pull_progress", "imagemirror", "imagecredential")):
            continue
        filtered[key] = value
    return filtered

def should_scan(path: Path) -> bool:
    name = path.name.lower()
    return name.endswith((".yml", ".yaml", ".yml.j2", ".yaml.j2", ".j2", ".tmpl", ".tpl"))

VAR_PATTERN = re.compile(r"^\s*(?P<name>[A-Za-z0-9_.-]*image[A-Za-z0-9_.-]*)\s*[:=]\s*(?P<value>.+)$")
FIELD_PATTERN = re.compile(r"^\s*(?:-\s*)?image\s*[:=]\s*(?P<value>.+)$")

SKIP_DIRS = {".git", ".github", ".tox", "__pycache__", ".mypy_cache", ".pytest_cache", ".idea", ".vscode"}

def clean_value(raw: str) -> str:
    value = raw.strip()
    if not value:
        return value
    if "#" in value and not value.lstrip().startswith("#"):
        value = value.split("#", 1)[0].rstrip()
    value = value.strip()
    if len(value) >= 2 and value[0] in ("'", '"') and value[-1] == value[0]:
        value = value[1:-1]
    return value.strip()

def static_scan(root: Path) -> dict:
    variables = []
    image_fields = []

    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for filename in filenames:
            file_path = Path(dirpath) / filename
            if not should_scan(file_path):
                continue
            try:
                with file_path.open("r", encoding="utf-8", errors="ignore") as handle:
                    lines = handle.readlines()
            except (OSError, UnicodeDecodeError):
                continue

            relative_path = str(file_path.relative_to(root))

            for index, line in enumerate(lines, start=1):
                stripped = line.strip()
                if not stripped or stripped.startswith(("#", "//")):
                    continue

                field_match = FIELD_PATTERN.match(line)
                if field_match:
                    raw_value = field_match.group("value")
                    cleaned = clean_value(raw_value)
                    image_fields.append(
                        {
                            "file": relative_path,
                            "line": index,
                            "value": cleaned,
                            "raw": raw_value.strip(),
                        }
                    )
                    continue

                var_match = VAR_PATTERN.match(line)
                if var_match:
                    key = var_match.group("name").strip()
                    lower_key = key.lower()
                    if lower_key == "image" or lower_key.endswith("images"):
                        continue
                    if any(token in lower_key for token in ("imagepull", "image_policy", "imagecredential", "imagemirror")):
                        continue
                    raw_value = var_match.group("value")
                    cleaned = clean_value(raw_value)
                    variables.append(
                        {
                            "name": key,
                            "file": relative_path,
                            "line": index,
                            "value": cleaned,
                            "raw": raw_value.strip(),
                        }
                    )

    return {
        "variables": variables,
        "image_fields": image_fields,
    }

ansible_image_vars = load_ansible_image_vars(ansible_json_path)
static_data = static_scan(kubespray_dir)

unique_values = []
seen = set()

def add_value(candidate):
    if not candidate:
        return
    normalized = str(candidate).strip()
    if not normalized or normalized in {">", ">-", "|", "|-"}:
        return
    if normalized in seen:
        return
    seen.add(normalized)
    unique_values.append(normalized)

for value in ansible_image_vars.values():
    if isinstance(value, str):
        add_value(value)
    elif isinstance(value, (list, tuple)):
        for item in value:
            if isinstance(item, str):
                add_value(item)

for entry in static_data["variables"]:
    add_value(entry.get("value"))

for entry in static_data["image_fields"]:
    add_value(entry.get("value"))

static_data["summary"] = {
    "variables_found": len(static_data["variables"]),
    "image_fields_found": len(static_data["image_fields"]),
}

static_json_path.write_text(json.dumps(static_data, indent=2, sort_keys=True))

generated_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")

report_payload = {
    "scenario": scenario_name,
    "generated_at": generated_at,
    "inventory": str(inventory_path),
    "ansible_image_variables_count": len(ansible_image_vars),
    "ansible_image_variables": ansible_image_vars,
    "static_scan": static_data,
    "unique_image_strings": sorted(unique_values),
    "unique_image_count": len(unique_values),
}

report_json_path.write_text(json.dumps(report_payload, indent=2, sort_keys=True))
PY

  REPORT_FILES+=("$report_json")
  echo "Scenario '$scenario' report: $report_json"
done

GLOBAL_REPORT="$OUTPUT_ROOT/kubespray-images-report-all.json"

python3 - "$GLOBAL_REPORT" "${REPORT_FILES[@]}" <<'PY'
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

dest = Path(sys.argv[1]).resolve()
sources = [Path(p).resolve() for p in sys.argv[2:]]

union = []
seen = set()
scenario_summaries = []

for path in sources:
    if not path.exists():
        continue
    data = json.loads(path.read_text())
    scenario = data.get("scenario", path.parent.name)
    images = data.get("unique_image_strings", [])
    scenario_summaries.append(
        {
            "scenario": scenario,
            "unique_image_count": len(images),
            "report_path": str(path),
        }
    )
    for item in images:
        if not item:
            continue
        norm = str(item).strip()
        if not norm or norm in seen:
            continue
        seen.add(norm)
        union.append(norm)

payload = {
    "generated_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "scenarios": scenario_summaries,
    "unique_image_strings": sorted(union),
    "unique_image_count": len(union),
}

dest.write_text(json.dumps(payload, indent=2, sort_keys=True))
PY

echo "Global union report written to: $GLOBAL_REPORT"
echo "Processed scenarios: ${SCENARIO_NAMES[*]}"
