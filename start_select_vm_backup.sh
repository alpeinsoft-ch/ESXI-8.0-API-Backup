#!/usr/bin/env bash
set -euo pipefail
umask 077

cd "$(dirname "$0")"

PYTHON_BIN="python3"
USING_VENV=0

check_modules() {
  set +e
  "$PYTHON_BIN" - <<'PY'
import importlib.util
import sys

missing = [module for module in ("pyVmomi", "requests") if importlib.util.find_spec(module) is None]
if missing:
    print(",".join(missing))
    sys.exit(7)
PY
  local status=$?
  set -e
  return "$status"
}

use_system_python() {
  PYTHON_BIN="python3"
  USING_VENV=0
}

if [ -x ".venv/bin/python" ]; then
  PYTHON_BIN=".venv/bin/python"
  USING_VENV=1
else
  rm -rf .venv
  if python3 -m venv --system-site-packages .venv >/dev/null 2>&1; then
    PYTHON_BIN=".venv/bin/python"
    USING_VENV=1
  else
    rm -rf .venv
    echo "Hinweis: python3-venv ist nicht verfuegbar; nutze System-Python." >&2
    use_system_python
  fi
fi

if ! check_modules; then
  if [ "$USING_VENV" -eq 1 ] && "$PYTHON_BIN" -m pip --version >/dev/null 2>&1; then
    "$PYTHON_BIN" -m pip install -r requirements.txt
  elif [ "$USING_VENV" -eq 1 ]; then
    echo "Hinweis: lokale venv hat kein pip; versuche System-Python." >&2
    rm -rf .venv
    use_system_python
  fi
fi

if ! check_modules; then
  echo "Fehlende Python-Module auf diesem Rechner: pyVmomi/requests" >&2
  echo "Empfohlen:" >&2
  echo "  sudo apt install python3-venv" >&2
  echo "  ./start_select_vm_backup.sh" >&2
  echo "Alternative:" >&2
  echo "  python3 -m pip install --user -r requirements.txt" >&2
  exit 7
fi

DEFAULT_SELECTION_FILE="vm_backup_selection.txt"
if [ "$#" -eq 0 ] && [ -f "$DEFAULT_SELECTION_FILE" ] && [ -t 0 ]; then
  echo "Auswahl-Datei gefunden: $DEFAULT_SELECTION_FILE"
  printf "Diese Datei fuer Listen-Backup nutzen? [j/N]: "
  read -r answer
  case "$(printf '%s' "$answer" | tr '[:upper:]' '[:lower:]')" in
    j|ja|y|yes)
      exec "$PYTHON_BIN" select_vm_backup.py --selection-file "$DEFAULT_SELECTION_FILE"
      ;;
  esac
fi

exec "$PYTHON_BIN" select_vm_backup.py "$@"
