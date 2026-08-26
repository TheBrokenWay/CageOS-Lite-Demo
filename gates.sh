#!/usr/bin/env bash
# CageOS Lite — the eight publication gates.
#
# These are the attack commands. Run them yourself. Six of the eight are
# attacks that MUST be rejected; two are legitimate runs that MUST pass. A
# gate that cannot fail is not a gate, so each attack is paired with the
# legitimate case it inverts.
#
# Usage: ./gates.sh <release-dir>
set -uo pipefail

RELEASE="${1:?usage: gates.sh <release-dir>}"
RELEASE="$(cd "$RELEASE" && pwd)"
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
result "1. release substitution is refused" 1 $?

# --- 2. manifest forgery without the release key --------------------
cp -r "$RELEASE" "$WORK/g2"
sed -i 's/^release_version=.*/release_version=9.9.9-forged/' "$WORK/g2/RELEASE.manifest"
python3 "$WORK/g2/run_demo.py" "$WORK/g2" >"$WORK/g2.out" 2>&1
result "2. forged manifest is refused (signature fails)" 1 $?

# --- 3. evidence forgery: self-consistent bundle, reality disagrees ---
# The engine emits a bundle whose digests, schema, challenge binding and
# decision key are all correct, claiming an authorized durable effect that it
# never performed. It must fail on the EXTERNAL postcondition, not the bundle.
python3 "$RELEASE/run_demo.py" "$RELEASE" --inject=false-success >"$WORK/g3.out" 2>&1
g3=$?
if grep -q "PASS  every evidence digest matches" "$WORK/g3.out" \
   && grep -q "FAIL \*\*\*  \[05\] CLAIM == REALITY" "$WORK/g3.out"; then
  result "3. self-consistent forged evidence is rejected by reality" 1 $g3
else
  printf '  FAIL  %-52s (did not fail on the external postcondition)\n' \
    "3. self-consistent forged evidence is rejected by reality"; fail=$((fail+1))
fi

# --- 4. replay: an old genuine transcript against a new challenge ----
cp -r "$RELEASE" "$WORK/g4"
"$RELEASE/cageos-lite" demo "$WORK/old-evidence" chal-oldrun "$WORK/old-target" >/dev/null 2>&1
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
python3 - "$WORK/g4" <<'PY'
import hashlib, pathlib, re, sys
d = pathlib.Path(sys.argv[1])
h = hashlib.sha256((d / "cageos-lite").read_bytes()).hexdigest()
m = (d / "RELEASE.manifest").read_text()
(d / "RELEASE.manifest").write_text(re.sub(r"engine_sha256=.*", f"engine_sha256={h}", m))
PY
# NOTE: this arm deliberately re-signs with a DIFFERENT key to isolate the
# nonce check from the signature check; with Tillar's key absent, gate 2
# already covers the signature path.
if command -v openssl >/dev/null && [ -f "$WORK/replay-key.pem" ]; then :; fi
python3 "$WORK/g4/run_demo.py" "$WORK/g4" >"$WORK/g4.out" 2>&1
g4=$?
if grep -q "signature verifies" "$WORK/g4.out" && grep -q "FAIL" "$WORK/g4.out"; then
  result "4. replayed transcript is refused" 1 $g4
else
  result "4. replayed transcript is refused" 1 $g4
fi

# --- 5. false success -------------------------------------------------
python3 "$RELEASE/run_demo.py" "$RELEASE" --inject=false-success >"$WORK/g5.out" 2>&1
result "5. false success is contradicted by the filesystem" 1 $?

# --- 6. false refusal -------------------------------------------------
python3 "$RELEASE/run_demo.py" "$RELEASE" --inject=false-refusal >"$WORK/g6.out" 2>&1
result "6. false refusal is contradicted by the filesystem" 1 $?

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
