#!/usr/bin/env bash
# ==============================================================================
# arcade-check.sh
# Run arcade-agent architecture analysis, drift detection, and rule validation
# for Stanford CoreNLP.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Resolve arcade-agent Python interpreter
# Resolve arcade-agent home
ARCADE_HOME="${ARCADE_AGENT_HOME:-${HOME}/Projects/tuannx/arcade-agent}"

if [ -n "${ARCADE_PYTHON:-}" ] && [ -x "${ARCADE_PYTHON}" ]; then
  PYTHON="${ARCADE_PYTHON}"
elif [ -x "${ARCADE_HOME}/.venv/bin/python" ]; then
  PYTHON="${ARCADE_HOME}/.venv/bin/python"
elif command -v arcade-arch-diff >/dev/null 2>&1; then
  PYTHON="python3"
else
  echo "[!] arcade-agent environment not found. Please set ARCADE_PYTHON or ARCADE_AGENT_HOME."
  exit 1
fi

REPORT_DIR="${ROOT_DIR}/arcade-report"
mkdir -p "${REPORT_DIR}"

echo "=================================================================="
echo " Running arcade-agent Architecture Verification on CoreNLP"
echo "=================================================================="

# 1. Architecture Drift Detection against .arcade/baseline.json
echo ""
echo "[1/2] Checking architecture drift against stored baseline..."
if [ -f "${ROOT_DIR}/.arcade/baseline.json" ]; then
  "${PYTHON}" -m arcade_agent.ci.arch_diff --source "${ROOT_DIR}/src" --language java --baseline "${ROOT_DIR}/.arcade/baseline.json" > "${REPORT_DIR}/drift-report.md" 2>&1 || true
  cat "${REPORT_DIR}/drift-report.md"
else
  echo "[-] Baseline not found at .arcade/baseline.json. Generating initial baseline..."
  "${PYTHON}" -m arcade_agent.ci.arch_diff --source "${ROOT_DIR}/src" --language java --update-baseline
fi

# 2. Rule Validation against .arcade-rules.json (if arcade-analyze-skill is available)
SKILL_VALIDATE=""
if [ -f "${HOME}/Projects/tuannx/arcade-analyze-skill/scripts/validate.py" ]; then
  SKILL_VALIDATE="${HOME}/Projects/tuannx/arcade-analyze-skill/scripts/validate.py"
elif [ -n "${ARCADE_SKILL_HOME:-}" ] && [ -f "${ARCADE_SKILL_HOME}/scripts/validate.py" ]; then
  SKILL_VALIDATE="${ARCADE_SKILL_HOME}/scripts/validate.py"
fi

if [ -n "${SKILL_VALIDATE}" ] && [ -f "${ROOT_DIR}/.arcade-rules.json" ]; then
  echo ""
  echo "[2/2] Validating architecture rules against .arcade-rules.json..."
  "${PYTHON}" "${SKILL_VALIDATE}" "${ROOT_DIR}" \
    --arcade-home "${ARCADE_HOME}" \
    --rules "${ROOT_DIR}/.arcade-rules.json" \
    --language java \
    --algorithm pkg \
    --output "${REPORT_DIR}/validation-report.md"
fi

echo ""
echo "=================================================================="
echo " Architecture check completed successfully!"
echo " Reports available in: ${REPORT_DIR}"
echo "=================================================================="
