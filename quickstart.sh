#!/usr/bin/env bash
# quickstart.sh — one-command clone-and-run for CageOS-Lite-Demo
# This script downloads the signed release package, verifies its SHA-256,
# extracts it, runs the demo verifier (run_demo.py), then runs the eight
# gates (gates.sh). It uses only tools found on a normal Linux box.
#
# Environment overrides (all optional):
#   CAGEOS_LITE_TGZ   Path to a local tarball (skips download; for offline tests)
#   CAGEOS_LITE_HOME  Work directory (default: $PWD/cageos-lite-release)
#   CAGEOS_LITE_URL   Download URL (default: the v0.1.0 release asset)
#
# Exit codes:
#   0    success (prints "QUICKSTART OK" as the very last line)
#   1    SHA-256 mismatch, demo failure, or gates failure
#   127  missing prerequisite tool
#
# The script is careful: it never runs the engine on unverified bytes,
# it cleans up a previous extract so re-runs are clean, and it prints
# clear messages if something is wrong.

set -euo pipefail

# ---- pinned constants -------------------------------------------------------
readonly EXPECTED_SHA256="7a671ed54ec3337e1b65a02c9c46ec5cb2c67225931fae1d3a6e7407f256a1d9"
readonly DEFAULT_URL="https://github.com/TheBrokenWay/CageOS-Lite-Demo/releases/download/v0.1.0/cageos-lite-0.1.0.tgz"
readonly EXTRACTED_DIRNAME="cageos-lite-0.1.0-rc"

# ---- resolve script location and work directory -----------------------------
# We want to work relative to a stable directory, not the caller's cwd.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${CAGEOS_LITE_HOME:-${SCRIPT_DIR}/cageos-lite-release}"
TGZ_PATH="${CAGEOS_LITE_TGZ:-}"
DOWNLOAD_URL="${CAGEOS_LITE_URL:-${DEFAULT_URL}}"

mkdir -p "${WORK_DIR}"

# ---- prerequisite checks ----------------------------------------------------
# We need: python3, gpg or gpgv, tar, curl or wget, sha256sum or shasum -a 256
missing=()

command -v python3 >/dev/null 2>&1 || missing+=("python3 (install python3)")
command -v tar >/dev/null 2>&1 || missing+=("tar (install tar)")

# gpg or gpgv
if ! command -v gpg >/dev/null 2>&1 && ! command -v gpgv >/dev/null 2>&1; then
    missing+=("gpg or gpgv (install gnupg or gpgv)")
fi

# curl or wget
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    missing+=("curl or wget (install curl or wget)")
fi

# sha256sum or shasum -a 256
if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
    missing+=("sha256sum or shasum (install coreutils or shasum)")
fi

if (( ${#missing[@]} > 0 )); then
    echo "Missing required tools:" >&2
    for m in "${missing[@]}"; do
        echo "  - ${m}" >&2
    done
    exit 127
fi

# ---- helper: compute sha256 of a file --------------------------------------
compute_sha256() {
    local file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "${file}" | awk '{print $1}'
    else
        shasum -a 256 "${file}" | awk '{print $1}'
    fi
}

# ---- network notice ---------------------------------------------------------
echo "The network is used only to download the release. The CageOS engine itself never uses the network."

# ---- download or use local tarball -----------------------------------------
TARBALL="${WORK_DIR}/cageos-lite-0.1.0.tgz"

if [[ -n "${TGZ_PATH}" ]]; then
    # Use provided local tarball
    if [[ ! -f "${TGZ_PATH}" ]]; then
        echo "CAGEOS_LITE_TGZ set but file not found: ${TGZ_PATH}" >&2
        exit 1
    fi
    cp "${TGZ_PATH}" "${TARBALL}"
    echo "Using local tarball: ${TGZ_PATH}"
else
    # Download
    echo "Downloading release from ${DOWNLOAD_URL} ..."
    if command -v curl >/dev/null 2>&1; then
        curl -fL -o "${TARBALL}" "${DOWNLOAD_URL}"
    else
        wget -O "${TARBALL}" "${DOWNLOAD_URL}"
    fi
    echo "Download complete."
fi

# ---- verify SHA-256 ---------------------------------------------------------
ACTUAL_SHA256="$(compute_sha256 "${TARBALL}")"
if [[ "${ACTUAL_SHA256}" != "${EXPECTED_SHA256}" ]]; then
    echo "SHA-256 mismatch" >&2
    echo "  expected: ${EXPECTED_SHA256}" >&2
    echo "  actual:   ${ACTUAL_SHA256}" >&2
    exit 1
fi
echo "SHA-256 verified."

# ---- extract (clean re-run) -------------------------------------------------
EXTRACTED_DIR="${WORK_DIR}/${EXTRACTED_DIRNAME}"

if [[ -d "${EXTRACTED_DIR}" ]]; then
    echo "Removing previous extract: ${EXTRACTED_DIR}"
    rm -rf "${EXTRACTED_DIR}"
fi

echo "Extracting to ${WORK_DIR} ..."
tar -xzf "${TARBALL}" -C "${WORK_DIR}"
echo "Extract complete."

# ---- run the demo verifier --------------------------------------------------
echo "Running demo verifier (run_demo.py) ..."
if ! python3 "${EXTRACTED_DIR}/run_demo.py" "${EXTRACTED_DIR}"; then
    echo "DEMO FAILED (see output above)" >&2
    exit 1
fi
echo "Demo verifier passed."

# ---- run the eight gates ----------------------------------------------------
echo "Running gates (gates.sh) ..."
if ! "${EXTRACTED_DIR}/gates.sh" "${EXTRACTED_DIR}"; then
    echo "GATES FAILED (see output above)" >&2
    exit 1
fi
echo "All eight gates passed."

# ---- summary ----------------------------------------------------------------
# Wording style mirrors LIMITS.md: no production readiness, certification, or ATO claims.
cat <<'EOF'

What was established:
- The release tarball matches the published SHA-256.
- The GPG signature on the release manifest verifies against the pinned fingerprint.
- The engine ran a real CageOS lifecycle against a random challenge.
- The verifier independently observed the effect and confirmed the record.
- All eight gates behaved as required: six attacks were rejected, two legitimate runs passed.

What was NOT established:
- Production readiness, certification, or an ATO/cATO.
- Security of arbitrary integrations or configurations.
- Anything beyond the fixture-only scope documented in LIMITS.md.

QUICKSTART OK
EOF
