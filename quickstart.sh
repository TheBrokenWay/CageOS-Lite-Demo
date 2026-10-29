#!/usr/bin/env bash
# quickstart.sh — one-command clone-and-run for CageOS-Lite-Demo
# This script downloads the signed release package, verifies its SHA-256,
# extracts it, runs the demo verifier (run_demo.py), then runs the eight
# gates (gates.sh). It runs only on Linux x86_64 and uses only tools found
# on a normal Linux box. Other platforms exit before any download.
#
# Environment overrides (all optional):
#   CAGEOS_LITE_TGZ   Path to a local tarball (skips download; for offline tests)
#   CAGEOS_LITE_HOME  Work directory (default: $PWD/cageos-lite-release)
#   CAGEOS_LITE_URL   Download URL (default: the v0.1.1 release asset)
#
# Exit codes:
#   0    success (prints "QUICKSTART OK" as the very last line)
#   1    unsupported platform, SHA-256 mismatch, demo failure, or gates failure
#   127  missing prerequisite tool
#
# The script is careful: it never runs the engine on unverified bytes,
# it cleans up a previous extract so re-runs are clean, and it prints
# clear messages if something is wrong.

set -euo pipefail

# ---- pinned constants -------------------------------------------------------
readonly EXPECTED_SHA256="45f06ca0ca025676a3971eacd77de424009411e6b4d056a1f1e2b55f38b67790"
readonly DEFAULT_URL="https://github.com/TheBrokenWay/CageOS-Lite-Demo/releases/download/v0.1.1/cageos-lite-0.1.1.tgz"
readonly EXTRACTED_DIRNAME="cageos-lite-0.1.1"

# ---- platform ---------------------------------------------------------------
# The signed engine and daemon are x86_64-unknown-linux-musl. Say so before
# any download. uname -m reports x86_64 on the machines this release supports.
OS_NAME="$(uname -s)"
ARCH_NAME="$(uname -m)"
if [[ "${OS_NAME}" != "Linux" || "${ARCH_NAME}" != "x86_64" ]]; then
    cat >&2 <<EOF
CageOS Lite runs only on Linux x86_64.
This machine reports: ${OS_NAME} ${ARCH_NAME}

The signed engine and daemon are static musl binaries built for
x86_64-unknown-linux-musl. macOS, Windows, and other architectures
(including aarch64 and arm64) are outside this release.
EOF
    exit 1
fi

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

# gpg itself (v0.1.1: gates.sh gate 4 mints a throwaway key, which gpgv cannot do)
if ! command -v gpg >/dev/null 2>&1; then
    missing+=("gpg (install gnupg; gpgv alone is not enough for gates.sh)")
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
TARBALL="${WORK_DIR}/cageos-lite-0.1.1.tgz"

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
# Agrees with LIMITS.md. The signed v0.1.1 driver still prints an older
# closing paragraph; this summary is the statement to keep.
cat <<'EOF'

What this run verified, on this machine:
- The release tarball matches the published SHA-256.
- The GPG signature on the release manifest matches the pinned Tillar Technologies fingerprint.
- The engine ran the fixture scenarios shipped with the release, against a challenge the verifier chose. No language model was loaded or called.
- The verifier read the filesystem itself. An authorized persistent write was observed: the target file existed, the challenge was in its content, and the digest matched. A refused persistent target was byte-for-byte unchanged.
- All eight gates behaved as required: six attacks were rejected, two legitimate runs passed. A clean run is 58 of 58 checks.

What this run did not verify:
- A witness on a separate machine. The verifier and the files it reads share this host, so a hostile administrator can roll the local state and the local witness back together. No independently operated off-host witness is accepted yet. Post-reboot persistence is unmeasured.
- Production readiness, an ATO or cATO, certification, or agency approval.
- Supervision of a live agent. The scenarios are fixtures. False-success and false-refusal injections are separate commands (python3 run_demo.py . --inject=false-success and --inject=false-refusal) and are caught by the same filesystem reads.

The signed v0.1.1 driver still ends by saying it cannot yet independently witness an AUTHORIZED write, because a bounded capability disposes of the artifact. That sentence describes the disposable scratch scenarios, whose cleanup guard removes the file on purpose. Section H of the same run is the persistent-write observation, and it passed. The repository LIMITS.md states the same boundary. The copy of the driver inside the signed tarball changes on the next signed release.

QUICKSTART OK
EOF
