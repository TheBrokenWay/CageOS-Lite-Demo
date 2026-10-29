# CageOS Lite v0.1.1 — release notes

**Linux x86_64 / static musl. Signed by Tillar Technologies. Gate hardening
release: the engine, daemon and verifier are byte-identical to v0.1.0.**

```
Archive:         cageos-lite-0.1.1.tgz
Archive SHA-256: 45f06ca0ca025676a3971eacd77de424009411e6b4d056a1f1e2b55f38b67790
Release signer:  CD62DA5B5F9F3E694C1D5536A182E6E145D573FB
Platform:        linux-x86_64, ELF, static-musl
```

## What changed, and why

v0.1.0's `gates.sh` judged five of its six attacks by exit code alone. A
broken release exits 1 just as a correctly rejected attack does, so those
gates could print PASS without showing that the attack was rejected for the
reason the gate claims. We reproduced this before changing anything:

- With `RELEASE.manifest.sig` deleted from a v0.1.0 package, `gates.sh`
  printed PASS for gates 1, 2, 4, 5 and 6 (the other three failed, so the
  run as a whole did not read 8/8).
- With the driver's replay check (`bound = all(...)` in `run_demo.py`)
  disabled in a test copy and re-sealed with a throwaway key, v0.1.0's
  `gates.sh` still printed **8 of 8**. Gate 4 never reached the replay check:
  its test edited the signed manifest, so the signature check stopped it
  first. It exercised the signature, not the replay logic.
- With the driver's signature-valid check disabled the same way, v0.1.0's
  `gates.sh` also still printed 8 of 8.

v0.1.1 changes only `gates.sh` (and two lines of `README.md`):

- Gates 1, 2, 4, 5 and 6 now require the specific refusal reason and a
  control line showing the release itself was healthy, in addition to exit
  code 1. Gate 1 and 2 also require that the engine never started.
- Gate 4 now isolates the replay check. It mints a throwaway key, builds a
  test copy that trusts only that key (the shipped driver and the pinned
  fingerprint are untouched), and runs two arms: a control with the genuine
  engine, which must pass, and a replay of an old genuine transcript, which
  must pass the signature and engine-hash checks and then be refused because
  its records are not bound to the new challenge.
- **New requirement:** `gates.sh` needs the full `gpg` command, not only
  `gpgv`, to mint that throwaway key. Without `gpg`, gate 4 fails closed and
  says why. `run_demo.py` still needs only `gpg` or `gpgv`.

Gates 5 and 6 were hardened in the same way because they had the same
exit-code-only weakness, although only gates 1, 2 and 4 were named when the
work was ordered.

Gate 4 tests the driver's replay check on a throwaway-signed copy. Whether
the real release is intact is established by gates 1, 2 and 8 and by the
signature check, not by gate 4.

## What did not change

| File | v0.1.0 | v0.1.1 |
|---|---|---|
| `cageos-lite` (engine) | `a28721ae…ba3c9f` | identical |
| `cageos_lifecycle_daemon` | `d0718880…d4c34c` | identical |
| `run_demo.py` | `d7374f1b…c7ce5` | identical |
| `LIMITS.md` | `77552e4f…3da6a0` | identical |
| `gates.sh` | `d25eb4da…21c90` | **changed** |
| `README.md` | `65819998…91b8c` | **changed** (v0.1.1 platform line, `gpg` note for gates) |

`built_from_commit` in the manifest is still the commit the binaries were
built from (`cf8877da…`). The v0.1.1 `gates.sh` and `README.md` changes are
in this repository, not in that commit. The binaries were not rebuilt.

## Verification results

Run on the build machine, from a fresh extraction of the archive in a
separate directory, by `verify_release.sh`-style checks that recompute the
hashes independently of `run_demo.py`:

```
archive sha256 45f06ca0ca025676a3971eacd77de424009411e6b4d056a1f1e2b55f38b67790
  PASS  exactly 10 files in the package (8 shipped + manifest + signature)
  PASS  signature valid and signer equals the pinned full fingerprint
  PASS  packaged .asc and .gpg keys both carry the pinned fingerprint
  PASS  six signed artifact hashes match (6 of 6)
  PASS  cageos-lite is an ELF with no program interpreter (static)
  PASS  cageos_lifecycle_daemon is an ELF with no program interpreter (static)
payload digest before testing  d1784c995b1587f50586a0e5357e856205b6cf89bbf3fc3cb8a52815bde43b9a
  PASS  run_demo.py: exit 0 and ALL 58 CHECKS PASS
  PASS  gates.sh: exit 0 and 8 of 8 gates
  PASS  1. release substitution is refused                   (exit 1, for the stated reason)
  PASS  2. forged manifest is refused (signature fails)      (exit 1, for the stated reason)
  PASS  3. self-consistent forged evidence is rejected by reality (exit 1 as required)
  PASS  4. replayed transcript is refused                    (exit 1, for the stated reason)
  PASS  5. false success is contradicted by the filesystem   (exit 1, for the stated reason)
  PASS  6. false refusal is contradicted by the filesystem   (exit 1, for the stated reason)
  PASS  8. clean run from a fresh directory passes           (exit 0 as required)
  PASS  7. legitimate idempotency passes                     (same decision key, no second decision)
payload digest after testing   d1784c995b1587f50586a0e5357e856205b6cf89bbf3fc3cb8a52815bde43b9a
  PASS  payload digest unchanged by testing
  PASS  signature still valid after testing
VERIFY RESULT: 10 passed, 0 failed
```

**Not repeated for v0.1.1: the second-machine validation that v0.1.0 had**
(separate host, glibc 2.28, Python 3.6.8, gpgv 2.2.20). The v0.1.1 gate 4
also needs `gpg`, which that host's validation did not exercise. Treat
v0.1.1 as verified on the build machine only until that is done.

## Known wording defect in the signed driver

`run_demo.py` in the signed v0.1.1 tarball ends with this paragraph:

> this demo cannot yet independently witness an AUTHORIZED write, because its
> bounded capability disposes of the artifact by design.

That sentence describes the disposable scratch scenarios, whose cleanup guard
removes the artifact on purpose. The same run's section H observes an
authorized persistent write on the host running the verifier: the target file
exists, the challenge is in its content, and the digest matches. A refused
persistent target is byte-for-byte unchanged. The gap that remains is the one
stated in the "where the witness sits" section of LIMITS.md in this
repository: no independently operated witness on a separate machine.

The signed tarball is untouched: its `run_demo.py` still prints the old
paragraph, and its `LIMITS.md` does not yet have the "where the witness sits"
section. The copies in git do. Shipping those copies means a new manifest
hash and a new signature, which is the next signed release. This change does
not re-sign v0.1.1.

## What release signing establishes, and what it does not

Unchanged from v0.1.0. A valid signature proves Tillar Technologies signed
this release manifest. It does not prove the software's runtime claims;
independent observation by the verifier does that, and only for the bounded,
fixture-only scenarios shipped. Neither proves production readiness, ATO,
cATO, certification, agency approval or general host integrity. The signing
key lives in the keyring of a networked developer workstation, not an air gap
or hardware token. See [LIMITS.md](../LIMITS.md).

## Reproducing our result

```bash
sha256sum cageos-lite-0.1.1.tgz     # expect the archive digest above
tar xzf cageos-lite-0.1.1.tgz && cd cageos-lite-0.1.1
gpgv --keyring ./tillar-release-key.gpg RELEASE.manifest.sig RELEASE.manifest
readelf -l cageos-lite | grep -c 'program interpreter'   # expect 0
python3 run_demo.py .                                     # expect ALL 58 CHECKS PASS
./gates.sh .                                              # expect 8 of 8 (needs gpg)
```

The archive is transport only; the signed object is `RELEASE.manifest` and
the files it authenticates.
