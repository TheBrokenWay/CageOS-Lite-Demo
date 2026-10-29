#!/usr/bin/env bash
# CageOS Lite — the eight publication gates.
#
# These are the attack commands. Run them yourself. Six of the eight are
# attacks that MUST be rejected; two are legitimate runs that MUST pass. A
# gate that cannot fail is not a gate, so each attack is paired with the
# legitimate case it inverts.
#
# v0.1.1: an attack that is refused for the WRONG reason no longer counts. Each
# attack gate now checks the exit code AND the specific reason it was refused,
# plus a control line showing the release itself was healthy. Before, gates 1,
# 2, 4, 5 and 6 printed PASS on a release directory that was simply broken
# (for example with its signature file deleted), because a missing file also
# exits 1. Gate 4 now isolates the replay check with a throwaway key, so it
# needs `gpg` (not only `gpgv`) to mint that key. Without gpg gate 4 FAILS
# closed and says so.
#
# Usage: ./gates.sh <release-dir>
set -uo pipefail

RELEASE="${1:?usage: gates.sh <release-dir>}"
if [ -d "$RELEASE" ]; then
  RELEASE="$(cd "$RELEASE" && pwd)"
fi
if [ ! -f "$RELEASE/RELEASE.manifest" ]; then
  cat >&2 <<EOF
This directory is not a signed CageOS Lite release, so there is nothing to attack yet.

  ${RELEASE}

gates.sh runs its eight gates against the engine, the daemon, and
RELEASE.manifest. Those files ship in the release tarball. They are not in
the git clone.

If that path was meant to be a release directory, it does not contain
RELEASE.manifest. From the repository root, the way to fetch the signed
package is:

    ./quickstart.sh

That downloads the signed release, checks its SHA-256, and runs the demo and
these gates. The release directory is:

    cageos-lite-release/cageos-lite-0.1.1
EOF
  exit 1
fi
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0; fail=0
result() { # name expected_exit actual_exit
  if [ "$2" -eq "$3" ]; then
    printf '  PASS  %-52s (exit %s as required)\n' "$1" "$3"; pass=$((pass+1))
  else
    printf '  FAIL  %-52s (exit %s, expected %s)\n' "$1" "$3" "$2"; fail=$((fail+1))
  fi
}

# refused_for NAME ACTUAL_EXIT OUTFILE PATTERN...
# The attack must exit 1 AND every PATTERN (fixed string) must appear in the
# output. A PATTERN starting with ! must be ABSENT. This is what makes a gate
# say WHY it passed: "refused", not merely "did not exit 0".
refused_for() {
  local name="$1" actual="$2" outf="$3"; shift 3
  local missing="" p
  [ "$actual" -eq 1 ] || missing="exit=$actual (wanted 1); "
  for p in "$@"; do
    if [ "${p:0:1}" = "!" ]; then
      ! grep -qF -- "${p:1}" "$outf" || missing="${missing}unexpected [${p:1}]; "
    else
      grep -qF -- "$p" "$outf" || missing="${missing}missing [$p]; "
    fi
  done
  if [ -z "$missing" ]; then
    printf '  PASS  %-52s (exit 1, for the stated reason)\n' "$name"; pass=$((pass+1))
  else
    printf '  FAIL  %-52s (refused for the wrong reason or not at all: %s)\n' "$name" "$missing"; fail=$((fail+1))
  fi
}

echo "CageOS Lite — eight publication gates"
echo "======================================================================"
echo "Six attacks that must be REJECTED, two legitimate runs that must PASS."
echo

# --- 1. release substitution ----------------------------------------
cp -r "$RELEASE" "$WORK/g1"
python3 - "$WORK/g1/cageos-lite" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); b = bytearray(p.read_bytes()); b[1000] ^= 0xFF; p.write_bytes(bytes(b))
PY
python3 "$WORK/g1/run_demo.py" "$WORK/g1" >"$WORK/g1.out" 2>&1
refused_for "1. release substitution is refused" $? "$WORK/g1.out" \
  "PASS  the release signature is valid" \
  "*** FAIL ***  the engine hash matches the signed manifest" \
  "REFUSING TO RUN a substituted engine" \
  "!FRESH CAGEOS EXECUTION"

# --- 2. manifest forgery without the release key --------------------
cp -r "$RELEASE" "$WORK/g2"
sed -i 's/^release_version=.*/release_version=9.9.9-forged/' "$WORK/g2/RELEASE.manifest"
python3 "$WORK/g2/run_demo.py" "$WORK/g2" >"$WORK/g2.out" 2>&1
refused_for "2. forged manifest is refused (signature fails)" $? "$WORK/g2.out" \
  "PASS  the release manifest is present" \
  "PASS  the release signature is present" \
  "PASS  the publisher keyring is present" \
  "*** FAIL ***  the release signature is valid" \
  "RELEASE AUTHENTICITY NOT VERIFIED" \
  "!FRESH CAGEOS EXECUTION"

# --- 3. evidence forgery: self-consistent bundle, reality disagrees ---
# The engine emits a bundle whose digests, schema, challenge binding and
# decision key are all correct, claiming an authorized durable effect that it
# never performed. It must fail on the EXTERNAL postcondition, not the bundle.
python3 "$RELEASE/run_demo.py" "$RELEASE" --inject=false-success >"$WORK/g3.out" 2>&1
g3=$?
if grep -q "PASS  every evidence digest matches" "$WORK/g3.out" \
   && grep -qF "PASS  the release signature is valid" "$WORK/g3.out" \
   && grep -q "FAIL \*\*\*  \[05\] CLAIM == REALITY" "$WORK/g3.out"; then
  result "3. self-consistent forged evidence is rejected by reality" 1 $g3
else
  printf '  FAIL  %-52s (did not fail on the external postcondition)\n' \
    "3. self-consistent forged evidence is rejected by reality"; fail=$((fail+1))
fi

# --- 4. replay: an old genuine transcript against a new challenge ----
# The v0.1.0 version of this gate swapped in a replay engine and edited the
# manifest, so the SIGNATURE check stopped it before the replay check ever ran.
# This version isolates the replay check. It mints a throwaway key, builds a
# test copy of the release that trusts ONLY that key (the shipped driver and the
# real pinned fingerprint are untouched), and runs two arms against it:
#   control : the genuine engine, validly signed by the throwaway key. Must PASS,
#             proving the test copy itself is healthy.
#   replay  : an old genuine transcript replayed as the engine, validly signed by
#             the same key. Signature and engine hash pass; the run must be
#             refused because the records are not bound to the NEW challenge.
G4NAME="4. replayed transcript is refused"
if ! command -v gpg >/dev/null 2>&1; then
  printf '  FAIL  %-52s (gpg is required to mint the throwaway key that isolates the replay check; gpgv alone cannot, so this fails closed)\n' "$G4NAME"; fail=$((fail+1))
else
  G4H="$WORK/g4gpg"; mkdir -p "$G4H"; chmod 700 "$G4H"
  gpg --homedir "$G4H" --batch --quiet --pinentry-mode loopback --passphrase '' \
      --quick-generate-key "cageos-gate4-throwaway" ed25519 sign 1d >"$WORK/g4keygen.out" 2>&1
  G4FPR="$(gpg --homedir "$G4H" --with-colons --list-keys 2>/dev/null | awk -F: '/^fpr:/{print $10; exit}')"
  gpg --homedir "$G4H" --export >"$WORK/g4key.gpg" 2>/dev/null
  # mk_arm DIR : copy the release, make it trust only the throwaway key, re-seal.
  mk_arm() {
    cp -r "$RELEASE" "$1"
    cp "$WORK/g4key.gpg" "$1/tillar-release-key.gpg"
    python3 - "$1" "$G4FPR" <<'PY'
import re, sys, pathlib
d = pathlib.Path(sys.argv[1]); fpr = sys.argv[2]
p = d / "run_demo.py"; s = p.read_text()
s2, n = re.subn(r'TILLAR_FINGERPRINT = "[0-9A-F]{40}"', 'TILLAR_FINGERPRINT = "%s"' % fpr, s)
assert n == 1; p.write_text(s2)
PY
  }
  # seal_arm DIR : recompute the hashes the driver checks, sign with the throwaway key.
  seal_arm() {
    python3 - "$1" <<'PY'
import hashlib, pathlib, re, sys
d = pathlib.Path(sys.argv[1]); m = (d / "RELEASE.manifest").read_text()
def h(n): return hashlib.sha256((d / n).read_bytes()).hexdigest()
m = re.sub(r"engine_sha256=.*", "engine_sha256=" + h("cageos-lite"), m)
m = re.sub(r"driver_sha256=.*", "driver_sha256=" + h("run_demo.py"), m)
(d / "RELEASE.manifest").write_text(m)
PY
    rm -f "$1/RELEASE.manifest.sig"
    gpg --homedir "$G4H" --batch --quiet --pinentry-mode loopback --passphrase '' \
        --local-user "$G4FPR" --detach-sign -o "$1/RELEASE.manifest.sig" "$1/RELEASE.manifest" 2>>"$WORK/g4keygen.out"
  }
  if [ -z "$G4FPR" ] || [ ! -s "$WORK/g4key.gpg" ]; then
    printf '  FAIL  %-52s (could not mint the throwaway key; see gpg output)\n' "$G4NAME"; fail=$((fail+1))
  else
    mk_arm "$WORK/g4c"; seal_arm "$WORK/g4c"
    python3 "$WORK/g4c/run_demo.py" "$WORK/g4c" >"$WORK/g4c.out" 2>&1
    g4c=$?
    "$RELEASE/cageos-lite" demo "$WORK/old-evidence" chal-oldrun "$WORK/old-target" >/dev/null 2>&1
    mk_arm "$WORK/g4"
    cat > "$WORK/g4/cageos-lite" <<PY
#!/usr/bin/env python3
import shutil, sys, os
# copytree(dirs_exist_ok=) is 3.8+; copy file by file so this runs on 3.6.
src = "$WORK/old-evidence"
os.makedirs(sys.argv[2], exist_ok=True)
for name in os.listdir(src):
    shutil.copy(os.path.join(src, name), os.path.join(sys.argv[2], name))
PY
    chmod +x "$WORK/g4/cageos-lite"
    seal_arm "$WORK/g4"
    python3 "$WORK/g4/run_demo.py" "$WORK/g4" >"$WORK/g4.out" 2>&1
    g4=$?
    if [ "$g4c" -ne 0 ]; then
      printf '  FAIL  %-52s (control arm failed, exit %s: the isolating test copy is not healthy)\n' "$G4NAME" "$g4c"; fail=$((fail+1))
    else
      refused_for "$G4NAME" $g4 "$WORK/g4.out" \
        "PASS  the release signature is valid" \
        "PASS  the signer is the pinned Tillar Technologies key" \
        "PASS  the engine hash matches the signed manifest" \
        "*** FAIL ***  every record is bound to THIS run's challenge"
    fi
  fi
  gpgconf --homedir "$G4H" --kill all >/dev/null 2>&1 || true
fi

# --- 5. false success -------------------------------------------------
python3 "$RELEASE/run_demo.py" "$RELEASE" --inject=false-success >"$WORK/g5.out" 2>&1
refused_for "5. false success is contradicted by the filesystem" $? "$WORK/g5.out" \
  "PASS  the release signature is valid" \
  "*** FAIL ***  [05] CLAIM == REALITY"

# --- 6. false refusal -------------------------------------------------
python3 "$RELEASE/run_demo.py" "$RELEASE" --inject=false-refusal >"$WORK/g6.out" 2>&1
refused_for "6. false refusal is contradicted by the filesystem" $? "$WORK/g6.out" \
  "PASS  the release signature is valid" \
  "*** FAIL ***  [05] OBSERVED: the refused action left nothing behind" \
  "*** FAIL ***  the demo root is byte-for-byte unchanged"

# --- 7 & 8. the legitimate runs --------------------------------------
python3 "$RELEASE/run_demo.py" "$RELEASE" >"$WORK/g8.out" 2>&1
g8=$?
result "8. clean run from a fresh directory passes" 0 $g8
if grep -q "PASS  re-presentation recovered a durable decision" "$WORK/g8.out"; then
  printf '  PASS  %-52s (same decision key, no second decision)\n' \
    "7. legitimate idempotency passes"; pass=$((pass+1))
else
  printf '  FAIL  %-52s\n' "7. legitimate idempotency passes"; fail=$((fail+1))
fi

echo
echo "======================================================================"
echo "  $pass of $((pass+fail)) gates behaved as required"
[ "$fail" -eq 0 ] && echo "  8/8 — the demonstration is internally honest." || echo "  NOT READY"
exit $(( fail > 0 ))
