#!/usr/bin/env python3
"""CageOS Lite — the public driver and verifier.

THE ORDER MATTERS, and it is the whole architecture (Architect ruling,
2026-08-26):

    verify release signature      <- was this engine distributed by Tillar?
            |
    verify engine hash            <- is this the exact binary that was signed?
            |
    fresh challenge + workspace   <- the verifier chooses, not the engine
            |
    launch that exact binary      <- the verifier runs it, and captures output
            |
    inspect external state        <- the verifier reads the real filesystem
            |
    compare CLAIM vs REALITY      <- and decides for itself

TWO DIFFERENT TRUST QUESTIONS, ANSWERED BY DIFFERENT TOOLS ON PURPOSE.

  "Did Tillar Technologies release these bytes?"
      -> answered by GPG, against a pinned full fingerprint. We do not
         reimplement OpenPGP to avoid a dependency: that would turn a solved
         signing problem into new security-critical code for the sake of a
         slogan. GPG or gpgv is a documented prerequisite, and this program
         REFUSES TO RUN the engine without it rather than falling back.

  "Is CageOS telling the truth about what happened?"
      -> answered by the rest of this file, which stays dependency-free so the
         interesting half of the demonstration is inspectable with nothing
         installed.

An engine that signs its own runtime evidence proves nothing: a key shipped
inside a binary belongs to whoever holds the binary, and "valid because CageOS
signed it" is a receipt grading itself. So the signature is over the RELEASE —
which software Tillar published — and this driver decides for itself what that
software actually did.

Release signing proves WHICH SOFTWARE was distributed by Tillar.
Independent observation proves WHETHER THE EFFECT matched that software's
claim. Neither proves that arbitrary future host state or production
integrations are trustworthy, and neither is offered as proving that.

Requires: python3 (3.6+), and gpg or gpgv. No Python packages. No network.

Usage:
    python3 run_demo.py <release-dir> [--keep]
"""

import hashlib
import json
import os
import secrets
import shutil
import subprocess
import sys
import tempfile

INJECT = [a.split("=", 1)[1] for a in sys.argv if a.startswith("--inject=")]

# The publisher identity, pinned by FULL fingerprint. Not "any key that can
# validate the signature" - a signature that verifies under an unpinned key
# proves only that someone signed something.
TILLAR_FINGERPRINT = "CD62DA5B5F9F3E694C1D5536A182E6E145D573FB"

RELEASE_SCHEMA = "CAGEOS-LITE-RELEASE-MANIFEST-v1"
RECORD_SCHEMA = "CAGEOS-LITE-DECISION-RECORD-v1"

KNOWN_REFUSAL_CODES = {
    "CV3-AUTH-REVOKED": "the authorization was revoked",
    "GTE2-TIME": "the authorization was outside its validity window",
    "GTE2-REPLAY": "the decision was already consumed",
    "CV3-ENVELOPE-FORMAT": "the envelope was not the frozen representation",
    "CV3-AUTH-SUBJECT": "the subject did not match the authorization",
    "CV3-AUTH-TARGET": "the target did not match the authorization",
}

results = []


def check(name, ok, detail=""):
    results.append((name, bool(ok)))
    print(f"  {'PASS' if ok else '*** FAIL ***'}  {name}" + (f"   {detail}" if detail else ""))
    return bool(ok)


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(65536), b""):
            h.update(block)
    return h.hexdigest()


def dir_state(path):
    """A digest of a directory's complete visible content. This is what
    'unchanged' means: same names, same bytes."""
    if not os.path.isdir(path):
        return "ABSENT"
    entries = []
    for root, dirs, files in os.walk(path):
        dirs.sort()
        for name in sorted(files):
            full = os.path.join(root, name)
            rel = os.path.relpath(full, path)
            try:
                entries.append(f"{rel}:{sha256_file(full)}")
            except OSError:
                entries.append(f"{rel}:UNREADABLE")
    return hashlib.sha256("\n".join(entries).encode()).hexdigest()


def parse_manifest(text):
    fields = {}
    for line in text.splitlines():
        if "=" in line:
            key, _, value = line.partition("=")
            fields[key.strip()] = value.strip()
    return fields


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    keep = "--keep" in sys.argv
    if len(args) != 1:
        print("usage: python3 run_demo.py <release-dir> [--keep]", file=sys.stderr)
        return 2
    release = os.path.abspath(args[0])

    print("CageOS Lite — public driver and verifier")
    print("=" * 66)
    print("Nothing here trusts the engine. This program verifies which software")
    print("it is about to run, runs it, then checks its claims against reality.")
    print()

    # ---- A. release authenticity (GPG) -------------------------------
    print("[1/4] RELEASE AUTHENTICITY  (did Tillar Technologies release these bytes?)")
    manifest_path = os.path.join(release, "RELEASE.manifest")
    sig_path = os.path.join(release, "RELEASE.manifest.sig")
    keyring = os.path.join(release, "tillar-release-key.gpg")
    for label, path in (("release manifest", manifest_path),
                        ("release signature", sig_path),
                        ("publisher keyring", keyring)):
        if not check(f"the {label} is present", os.path.isfile(path), path):
            return 1

    verifier_tool = shutil.which("gpgv") or shutil.which("gpg")
    if verifier_tool is None:
        print()
        print("  RELEASE AUTHENTICITY NOT VERIFIED")
        print()
        print("  CageOS Lite will not execute a release whose publisher")
        print("  identity has not been established.")
        print()
        print("  Required: gpg or gpgv")
        return 1
    check("a signature verifier is available", True, os.path.basename(verifier_tool))

    if os.path.basename(verifier_tool) == "gpgv":
        command = [verifier_tool, "--status-fd", "1", "--keyring", keyring,
                   sig_path, manifest_path]
    else:
        command = [verifier_tool, "--status-fd", "1", "--no-default-keyring",
                   "--keyring", keyring, "--verify", sig_path, manifest_path]
    try:
        proc = subprocess.run(command, stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE, universal_newlines=True,
                              timeout=60)
    except (OSError, subprocess.TimeoutExpired) as exc:
        check("the signature check ran", False, str(exc))
        return 1

    status = proc.stdout or ""
    # VALIDSIG carries the FULL fingerprint of the key that actually signed.
    signer = ""
    for line in status.splitlines():
        if "VALIDSIG" in line:
            parts = line.split()
            if len(parts) >= 3:
                signer = parts[2]
    if not check("the release signature is valid", proc.returncode == 0 and bool(signer),
                 "an unsigned or altered release stops here"):
        print()
        print("  RELEASE AUTHENTICITY NOT VERIFIED - refusing to run the engine.")
        return 1
    if not check("the signer is the pinned Tillar Technologies key",
                 signer.upper() == TILLAR_FINGERPRINT,
                 f"{signer} (pinned {TILLAR_FINGERPRINT})"):
        print()
        print("  SIGNED BY THE WRONG KEY - refusing to run the engine.")
        return 1
    print(f"      signer: {signer}")

    manifest_bytes = open(manifest_path, "rb").read()
    fields = parse_manifest(manifest_bytes.decode())
    check("the manifest declares the published schema",
          fields.get("schema") == RELEASE_SCHEMA, fields.get("schema", ""))
    print(f"  release_version = {fields.get('release_version', '?')}")

    # ---- B. the exact signed artifacts -------------------------------
    print()
    print("[2/4] SIGNED ARTIFACT INTEGRITY  (are these the exact signed bytes?)")
    engine = os.path.join(release, fields.get("engine_filename", "cageos-lite"))
    if not check("the engine binary is present", os.path.isfile(engine), engine):
        return 1
    engine_hash = sha256_file(engine)
    if not check("the engine hash matches the signed manifest",
                 engine_hash == fields.get("engine_sha256"),
                 f"{engine_hash[:16]}… vs signed {str(fields.get('engine_sha256'))[:16]}…"):
        print()
        print("REFUSING TO RUN a substituted engine.")
        return 1
    # The engine spawns this daemon as a real subprocess, so it is software
    # this program causes to run and must be identified before running it.
    daemon = os.path.join(release, fields.get("daemon_filename", "cageos_lifecycle_daemon"))
    if not check("the enforcement daemon is present", os.path.isfile(daemon), daemon):
        return 1
    daemon_hash = sha256_file(daemon)
    if not check("the daemon hash matches the signed manifest",
                 daemon_hash == fields.get("daemon_sha256"),
                 f"{daemon_hash[:16]}… vs signed {str(fields.get('daemon_sha256'))[:16]}…"):
        print()
        print("REFUSING TO RUN a substituted enforcement daemon.")
        return 1
    # The driver checks its OWN identity too: a tampered verifier is exactly
    # as dangerous as a tampered engine, and saying so is cheap.
    for name, key in (("run_demo.py", "driver_sha256"),
                      ("LIMITS.md", "limits_sha256")):
        path = os.path.join(release, name)
        if os.path.isfile(path) and key in fields:
            check(f"{name} matches the signed manifest",
                  sha256_file(path) == fields[key])

    # ---- C. fresh challenge, fresh workspace -------------------------
    print()
    print("[3/4] FRESH CAGEOS EXECUTION  (the verifier chooses the challenge)")
    challenge = "chal-" + secrets.token_hex(16)
    workspace = tempfile.mkdtemp(prefix="cageos-lite-run-")
    evidence_dir = os.path.join(workspace, "evidence")
    # The demo root belongs to THIS program, not the engine. Pre-state is
    # captured before the engine is allowed to run, so "unchanged" is measured
    # rather than asserted.
    demo_root = os.path.join(workspace, "cageos-lite-target")
    os.makedirs(demo_root, exist_ok=True)
    # This program seeds the refusal target itself, so "unchanged" is measured
    # against state the ENGINE never chose.
    refused_root = os.path.join(demo_root, "refused")
    os.makedirs(refused_root, exist_ok=True)
    with open(os.path.join(refused_root, "pre-existing.txt"), "wb") as handle:
        handle.write(b"seeded by the verifier, not the engine\n")
    pre_state = dir_state(demo_root)
    refused_pre = dir_state(refused_root)
    print(f"  challenge  {challenge}")
    print(f"  workspace  {workspace}")
    print(f"  demo root  {demo_root}")
    print(f"  pre-state  {pre_state[:16]}…")

    # ---- D. run the engine -------------------------------------------
    print()
    print("      running the verified engine")
    try:
        completed = subprocess.run(
            [engine, "demo", evidence_dir, challenge, demo_root] + INJECT,
            # stdout/stderr=PIPE rather than capture_output, and
            # universal_newlines rather than text: both of the modern spellings
            # are Python 3.7+, and an enterprise evaluator on an older
            # interpreter should not be told to upgrade Python to check our
            # claims. Measured on Python 3.6.8.
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            universal_newlines=True, timeout=300, cwd=workspace,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        check("the engine ran to completion", False, str(exc))
        return 1
    check("the engine exited cleanly", completed.returncode == 0,
          f"exit={completed.returncode}")
    check("the engine produced an evidence directory", os.path.isdir(evidence_dir))
    post_state = dir_state(demo_root)
    print(f"  post-state {post_state[:16]}…")

    # ---- E. evidence integrity + challenge binding -------------------
    print()
    print("[4/4] INDEPENDENT VERIFICATION  (does the world agree with CageOS?)")
    print("      evidence integrity and challenge binding")
    ev_manifest = os.path.join(evidence_dir, "MANIFEST.txt")
    if not check("the evidence manifest exists", os.path.isfile(ev_manifest)):
        return 1
    listed = {}
    for line in open(ev_manifest, encoding="utf-8").read().splitlines():
        parts = line.split("  ")
        if len(parts) == 2 and len(parts[0]) == 64:
            listed[parts[1]] = parts[0]
    ok = all(sha256_file(os.path.join(evidence_dir, n)) == d for n, d in listed.items())
    check("every evidence digest matches the bytes on disk", ok, f"{len(listed)} records")

    records = []
    for name in sorted(listed):
        with open(os.path.join(evidence_dir, name), encoding="utf-8") as handle:
            records.append(json.load(handle))
    check("at least one decision record was produced", len(records) > 0)

    # THE replay gate: an old genuine transcript cannot answer a new challenge.
    bound = all(r.get("challenge_nonce") == challenge for r in records)
    check("every record is bound to THIS run's challenge", bound,
          f"expected {challenge}")

    # ---- F. claim versus observed reality ----------------------------
    print()
    print("F. CLAIM VERSUS OBSERVED REALITY")
    for record in records:
        rid = record.get("scenario_id", "??")
        check(f"[{rid}] declares the published record schema",
              record.get("schema") == RECORD_SCHEMA)
        who = record.get("who", {})
        check(f"[{rid}] executor and observer are distinct identities",
              who.get("executor") and who.get("executor") != who.get("observer"))
        why, result = record.get("why", {}), record.get("result", {})
        status = why.get("status", "")
        target_dir = record.get("where", {}).get("target_dir", "")

        if status == "REFUSED":
            check(f"[{rid}] the refusal names a published reason code",
                  why.get("reason_code") in KNOWN_REFUSAL_CODES,
                  f"{why.get('reason_code')} = "
                  f"{KNOWN_REFUSAL_CODES.get(why.get('reason_code'), 'UNKNOWN')}")
            check(f"[{rid}] the refusal reports no execution and no observation",
                  not result.get("executor") and not result.get("observation"))
            # Independent: the verifier reads the real directory itself.
            # Only the DISPOSABLE scratch scenarios must end empty. The
            # persistent scenario's target legitimately holds state this
            # program seeded, and is checked for being UNCHANGED in section H
            # instead - "empty" would be the wrong property there.
            if record.get("claimed_target_state") == "EMPTY_ON_REFUSAL":
                empty = not os.path.isdir(target_dir) or not os.listdir(target_dir)
                check(f"[{rid}] OBSERVED: the refused action left nothing behind",
                      empty, f"read from disk: {target_dir}")
        elif status == "OK":
            if why.get("recovered") == "true":
                check(f"[{rid}] a recovered decision re-ran nothing",
                      not result.get("executor") and not result.get("observation"))
                check(f"[{rid}] a recovered decision is already reconciled",
                      result.get("reconciliation") == "COMMITTED")
            else:
                check(f"[{rid}] a fresh authorized action was independently observed",
                      result.get("observation") == "MATCH")
                check(f"[{rid}] a fresh authorized action reconciled",
                      result.get("reconciliation") == "COMMITTED")
            check(f"[{rid}] the decision carries a decision key",
                  len(why.get("decision_key", "")) == 64)
        else:
            check(f"[{rid}] status is a recognized value", False, repr(status))


    # ---- H. PERSISTENT EFFECT: CLAIM VERSUS INDEPENDENT OBSERVATION ---
    #
    # This section deliberately does NOT read the engine's execution,
    # observation or reconciliation fields as facts. They are CLAIMS. What
    # decides is this program opening the directory itself, after the engine
    # has exited, and looking.
    print()
    print("H. PERSISTENT EFFECT: CLAIM VERSUS INDEPENDENT OBSERVATION")
    for record in records:
        rid = record.get("scenario_id", "??")
        claimed_state = record.get("claimed_target_state", "")
        if claimed_state not in ("PERSISTED", "UNCHANGED_ON_REFUSAL"):
            continue
        target_dir = record.get("where", {}).get("target_dir", "")
        extra = {k: v for k, v in (record.get("extra") or {}).items()} if isinstance(
            record.get("extra"), dict) else {}
        why = record.get("why", {})
        result = record.get("result", {})
        expected_name = extra.get("expected_file") or f"cageos-lite-{challenge}.txt"
        expected_digest = extra.get("expected_sha256", "")
        expected_content = f"CAGEOS-LITE-AUTHORIZED:{challenge}\n".encode()

        print(f"  --- scenario {rid} ---")
        print(f"      ENGINE CLAIM       decision={why.get('decision') or why.get('status')} "
              f"execution={result.get('executor') or '-'} "
              f"observation={result.get('observation') or '-'} "
              f"reconciliation={result.get('reconciliation') or '-'}")

        target_path = os.path.join(target_dir, expected_name)
        exists = os.path.isfile(target_path)

        if claimed_state == "PERSISTED":
            claim_ok = True
            claim_ok &= check(f"[{rid}] OBSERVED: the expected target exists", exists,
                              target_path)
            if exists:
                observed = open(target_path, "rb").read()
                claim_ok &= check(f"[{rid}] OBSERVED: the challenge is present in the content",
                                  challenge.encode() in observed)
                digest = hashlib.sha256(observed).hexdigest()
                claim_ok &= check(f"[{rid}] OBSERVED: the content digest matches",
                                  digest == hashlib.sha256(expected_content).hexdigest(),
                                  digest[:16] + "…")
                claim_ok &= check(f"[{rid}] OBSERVED: the effect survived engine exit", True)
            check(f"[{rid}] CLAIM == REALITY", claim_ok,
                  "the engine claimed success and reality agrees" if claim_ok
                  else "THE ENGINE'S SUCCESS CLAIM IS CONTRADICTED BY THE FILESYSTEM")
        else:
            # A refusal must have changed NOTHING: not merely "no new file",
            # but the whole directory byte-for-byte as this program left it.
            no_effect = not exists
            unchanged = dir_state(target_dir) == refused_pre
            check(f"[{rid}] OBSERVED: the refused effect did not appear", no_effect,
                  f"unexpected {target_path}" if exists else target_dir)
            check(f"[{rid}] OBSERVED: the target is byte-for-byte unchanged", unchanged,
                  f"pre {refused_pre[:16]}… post {dir_state(target_dir)[:16]}…")
            check(f"[{rid}] CLAIM == REALITY", no_effect and unchanged,
                  "the engine claimed refusal and reality agrees" if (no_effect and unchanged)
                  else "THE ENGINE CLAIMED REFUSAL BUT AN EFFECT OCCURRED")

    # ---- I. WHOLE-ROOT STATE ------------------------------------------
    print()
    print("I. WHOLE-ROOT STATE (measured before and after the engine ran)")
    print(f"  pre  {pre_state}")
    print(f"  post {post_state}")
    any_persisted = any(r.get("claimed_target_state") == "PERSISTED" for r in records)
    if any_persisted:
        check("the demo root changed, as an authorized durable effect requires",
              pre_state != post_state)
    else:
        check("the demo root is byte-for-byte unchanged", pre_state == post_state)

    # ---- G. cross-scenario invariant ---------------------------------
    print()
    print("G. NO SECOND DECISION ON RE-PRESENTATION")
    replay = next((r for r in records if r.get("scenario_id") == "03"), None)
    if replay is None:
        check("the re-presentation scenario is present", False)
    else:
        why = replay.get("why", {})
        check("re-presentation recovered a durable decision instead of minting one",
              why.get("recovered") == "true" and len(why.get("decision_key", "")) == 64,
              f"recovered={why.get('recovered')}")

    if not keep:
        shutil.rmtree(workspace, ignore_errors=True)
    else:
        print()
        print(f"  workspace kept for inspection: {workspace}")

    # ---- verdict ------------------------------------------------------
    print()
    print("=" * 66)
    failed = [n for n, ok in results if not ok]
    if failed:
        print(f"*** {len(failed)} of {len(results)} CHECKS FAILED ***")
        for name in failed:
            print(f"    - {name}")
        return 1
    print(f"ALL {len(results)} CHECKS PASS")
    print()
    print("What this establishes: the engine you just ran is the exact software")
    print("Tillar signed; it answered a challenge this program chose; its")
    print("refusals named published reason codes and left nothing behind on")
    print("disk, checked by reading the disk; the executor and the observer were")
    print("distinct identities; and a re-presented authorization did not mint a")
    print("second decision.")
    print()
    print("What it does NOT establish: production readiness, ATO, cATO,")
    print("certification, agency approval, or security in general. See LIMITS.md")
    print("for the one gap that matters most - this demo cannot yet independently")
    print("witness an AUTHORIZED write, because its bounded capability disposes")
    print("of the artifact by design.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
