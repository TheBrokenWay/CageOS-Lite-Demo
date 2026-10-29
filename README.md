# CageOS Lite

**Don't trust this software. Attack it, then check its work.**

CageOS Lite is a small, signed, independently runnable proof of the CageOS
control pattern. A closed engine runs the fixture scenarios shipped with the
release through an authorize, execute, observe, reconcile, or refuse
lifecycle. A verifier you can read in this repository decides for itself
whether what the engine *claimed* is what actually *happened* on disk.

No language model is loaded, called, or supervised. A clean run is **58 of 58
checks** and **8 of 8 gates**. The verifier catches a false success, a false
refusal, and a release with one byte flipped. Those results cover the shipped
fixtures. Production readiness is a separate question, and this repository
does not claim it. See **[LIMITS.md](LIMITS.md)**.

The claim it exists to demonstrate:

> **A completely self-consistent forged CageOS evidence bundle still fails when
> independently observed reality contradicts it. The record is not privileged.**

That is gate 3 below, and you can run it yourself.

---

## Requirements

**Linux x86_64 only.** The signed engine and daemon are static musl binaries
for `x86_64-unknown-linux-musl`. macOS, Windows, and every other architecture,
including aarch64 and Apple Silicon, are outside this release. `quickstart.sh`
reads `uname` and exits before downloading when the machine is anything else.

Also required: Python 3.6 or newer, `gpg` (the gates mint a throwaway key;
`gpgv` alone is not enough for `gates.sh`), `tar`, `curl` or `wget`, and
`sha256sum` or `shasum`. No Python packages. No root. The network is used
only to download the release. The engine itself does not use the network.

## Run it from a fresh clone

This is the first-run path:

```bash
git clone https://github.com/TheBrokenWay/CageOS-Lite-Demo && cd CageOS-Lite-Demo && ./quickstart.sh
```

`quickstart.sh` downloads `cageos-lite-0.1.1`, checks the published SHA-256,
verifies the publisher signature, runs the demo, and runs the eight gates.
A good run ends with `ALL 58 CHECKS PASS`, `8 of 8 gates behaved as required`,
and `QUICKSTART OK`.

**Do not run `python3 run_demo.py` or `./gates.sh` in this clone.** The signed
engine, the daemon, and `RELEASE.manifest` are not in the git tree. Both
programs exit immediately and point back at `./quickstart.sh`.

The release is extracted to `cageos-lite-release/cageos-lite-0.1.1/`. To
re-run one check, use that directory:

```bash
cd cageos-lite-release/cageos-lite-0.1.1
python3 run_demo.py .                          # 58 checks
python3 run_demo.py . --inject=false-success   # claims success, does nothing
python3 run_demo.py . --inject=false-refusal   # claims refusal, acts anyway
./gates.sh .
```

The filesystem catches both injections, and those two commands exit 1. A clean
run is the command with no `--inject` flag.

## If you already have the tarball

Get `cageos-lite-0.1.1.tgz` from
[Releases](https://github.com/TheBrokenWay/CageOS-Lite-Demo/releases) and
confirm the bytes:

```bash
sha256sum cageos-lite-0.1.1.tgz
# 45f06ca0ca025676a3971eacd77de424009411e6b4d056a1f1e2b55f38b67790
tar xzf cageos-lite-0.1.1.tgz && cd cageos-lite-0.1.1
python3 run_demo.py .
./gates.sh .
```

Run `run_demo.py` and `gates.sh` in that extracted directory. The same
commands in the git clone do not find a release, and they stop with a pointer
to `./quickstart.sh`.

The first thing `run_demo.py` does is check that Tillar Technologies signed
this release, against a full fingerprint pinned in the source. Without `gpg`
or `gpgv` it **refuses to run the engine**.

Every decision prints a reconstructable record:

```
WHO     proposer / issuer / executor / observer / subject
WHAT    the requested action and its payload digest
WHERE   the target and scope it applies to
WHEN    validity window, judged by the engine's clock, not the request's
WHY     the decision, and the published reason code when refused
```

The record is the engine's claim. The verifier's finding is what it reads
from disk afterwards.

## What a passing run verifies

On this host, after the engine has exited, the verifier reads the filesystem
itself:

- An authorized persistent write was observed. The target file exists, the
  challenge the verifier chose is in its content, and the digest matches.
- A refused persistent target was byte-for-byte unchanged from the baseline
  the verifier seeded.
- Disposable scratch scenarios are removed by their cleanup guard. An empty
  directory there is not evidence of a durable write. The "left nothing
  behind" check applies to those scenarios, where an empty directory is the
  property that holds.
- A false success and a false refusal are contradicted by those same reads.
- A tampered release is refused before the engine runs. One flipped byte in
  the manifest, the engine, or the daemon is enough.

A passing run leaves the witness on this host. No independently operated
off-host witness is accepted yet. The verifier and the files it reads share
one machine, so a hostile administrator can roll the local state and the
local witness back together. Post-reboot persistence is unmeasured.

The signed v0.1.1 driver still ends with an older sentence: the demo "cannot
yet independently witness an AUTHORIZED write, because its bounded capability
disposes of the artifact by design." That sentence describes the disposable
scratch scenarios. Section H of the same run is the persistent-write
observation, and a clean run passes it. Believe section H and
[LIMITS.md](LIMITS.md). `quickstart.sh` repeats this after the driver exits,
because the process it launches is the signed copy.

The `run_demo.py` in this repository prints the corrected closing paragraph.
The copy inside `cageos-lite-0.1.1.tgz` still prints the old one. Replacing
the signed copy is a new manifest hash and a new signature. That is the next
signed release. This repository does not re-sign v0.1.1.

## The eight gates

| # | Gate | Establishes |
|---|---|---|
| 1 | Release substitution | One flipped byte and the driver refuses **before execution** |
| 2 | Manifest forgery | Recomputed hashes without our key fail the signature |
| 3 | **Evidence forgery** | An **internally flawless** bundle still loses to observed reality |
| 4 | Replay | An old genuine transcript cannot answer a fresh challenge |
| 5 | False success | A claimed effect that did not happen is contradicted by the filesystem |
| 6 | False refusal | A claimed refusal that did happen is contradicted by pre/post state |
| 7 | Idempotency | A re-presented authorization returns the same decision key |
| 8 | Clean run | Everything passes from a fresh directory |

In the gate 3 run, the forged bundle is internally perfect: every digest
matches, the challenge binding is correct, the schema conforms, the decision
key is present. It fails anyway, on checks that observe reality rather than
the bundle.

## Two different trust questions

```
  "Did Tillar Technologies release these bytes?"   -> GPG, pinned fingerprint
  "Is CageOS telling the truth about what happened?"  -> the verifier, no deps
```

They are deliberately separate. A release signature proves *which software you
have*. Independent observation proves *whether the effect matched the claim*
for the shipped fixtures, on the host where the verifier ran. Neither is an
off-host witness. Neither is a live-agent result. Neither is production
readiness. See **[LIMITS.md](LIMITS.md)**.

## Verify the publisher two ways

The signer fingerprint is published independently here and on our website. If
the two disagree, stop.

```
CD62DA5B 5F9F3E69 4C1D5536 A182E6E1 45D573FB
```

- this repository: [`FINGERPRINT`](FINGERPRINT), [`tillar-release-key.asc`](tillar-release-key.asc)
- https://tillartechnologies.com

## What is here, and what is not

**Here:** the verifier and gate runner you are asked to read (`run_demo.py`,
`gates.sh`), the limits, the public key, and the release documentation.
`quickstart.sh` executes the copies inside the signed tarball, not these
working-tree files. v0.1.1's manifest hashes `run_demo.py`, `gates.sh`, and
`LIMITS.md` as they were signed. The working tree now differs in the places
described above: the clone guard, the driver's closing paragraph, and the
witness section of LIMITS.md. Diff the tarball against this tree before
treating the two as the same bytes.

**Not here:** the enforcement implementation. The signed static engine and
daemon are the public executable proof surface; their source remains private.
That is the point — a locked door is demonstrated by attacking it, not by
handing over the lock.

**Not part of the signed demo:** `src/cagetutor/` and
[`docs/PREDX_LESSONS_FOR_CAGETUTOR.md`](docs/PREDX_LESSONS_FOR_CAGETUTOR.md).
Those files are an early sketch, from the first commit of this repository, of
a tutor-agent contract: a short description of what a course-tutor agent would
be allowed to read (rendered instructions and verdicts) and what it must not
read (gate source, the Math-X substrate, policy code, test harnesses). Nothing
in the verifier imports them. `quickstart.sh` does not run them. They are not
in the signed release. The modules that note names (`qframe.py`,
`sentinel_lite.py`, and the rest) are not in this repository.

## Scope

**v0.1.1: Linux x86_64, static musl.** Other architectures are outside this
release. Fixture scenarios throughout: an ATO, a cATO, a certification, an
agency approval, and a proof about arbitrary production integrations are
outside it too.

Background on where this came from: [docs/GENESIS.md](docs/GENESIS.md).
Release detail: [docs/RELEASE-v0.1.1.md](docs/RELEASE-v0.1.1.md) (current), [docs/RELEASE-v0.1.0.md](docs/RELEASE-v0.1.0.md).

Tillar Technologies LLC · Florida
