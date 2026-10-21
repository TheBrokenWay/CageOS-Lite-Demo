# CageOS Lite

**Don't trust this software. Attack it, then check its work.**

CageOS Lite is a small, signed, independently runnable proof of the CageOS
control pattern. A closed engine runs a real, fixture-only CageOS lifecycle on
your machine. A verifier — every line of which is in this repository — decides
for itself whether what the engine *claimed* is what actually *happened*.

The claim it exists to demonstrate:

> **A completely self-consistent forged CageOS evidence bundle still fails when
> independently observed reality contradicts it. The record is not privileged.**

That is gate 3 below, and you can run it yourself.

---

## Run it in one command

```bash
git clone https://github.com/TheBrokenWay/CageOS-Lite-Demo && cd CageOS-Lite-Demo && ./quickstart.sh
```

`run_demo.py` and `gates.sh` are the exact files shipped inside the signed release and need the release package, so do not run them from a git clone. `quickstart.sh` downloads the release, checks its SHA-256, and runs the demo and the eight gates for you. The network is used only for the download.

---

## Run it

**1. Download the release**

Get `cageos-lite-0.1.0.tgz` from
[Releases](https://github.com/TheBrokenWay/CageOS-Lite-Demo/releases), and
confirm you have the exact bytes we published:

```bash
sha256sum cageos-lite-0.1.0.tgz
# 7a671ed54ec3337e1b65a02c9c46ec5cb2c67225931fae1d3a6e7407f256a1d9
tar xzf cageos-lite-0.1.0.tgz && cd cageos-lite-0.1.0-rc
```

**2. Verify the publisher signature**

```bash
python3 run_demo.py .
```

The first thing it does is check that Tillar Technologies signed this release,
against a full fingerprint pinned in the source you are reading. Without `gpg`
or `gpgv` it **refuses to run the engine** rather than falling back.

**3. Run the demo** — the same command continues into a real CageOS run,
against a random challenge it chooses itself.

**4. Inspect who / what / where / when / why**

Every decision prints a reconstructable record, not an opaque score and not a
model's judgment:

```
WHO     proposer / issuer / executor / observer / subject
WHAT    the requested action and its payload digest
WHERE   the target and scope it applies to
WHEN    validity window, judged by the engine's clock, not the request's
WHY     the decision, and the published reason code when refused
```

**5. Attack it**

```bash
./gates.sh .
```

Eight gates: six attacks that must be **rejected**, two legitimate runs that
must **pass**. You can also trigger the lies directly:

```bash
python3 run_demo.py . --inject=false-success   # claims success, does nothing
python3 run_demo.py . --inject=false-refusal   # claims refusal, acts anyway
```

Both are caught by the filesystem, not by the record.

Requirements: Linux x86_64, Python 3.6+, and `gpg` or `gpgv`. No Python
packages, no network, no install, no root.

---

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
have*. Independent observation proves *whether the effect matched the claim*.
Neither proves production readiness. See **[LIMITS.md](LIMITS.md)**, which
states the boundaries in plain English.

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
`gates.sh`), the limits, the public key, and the release documentation. The
copies in this repository are byte-identical to the signed release, so you can
diff them against the manifest.

**Not here:** the enforcement implementation. The signed static engine and
daemon are the public executable proof surface; their source remains private.
That is the point — a locked door is demonstrated by attacking it, not by
handing over the lock.

## Scope

**v0.1.0: Linux x86_64, static musl.** ARM64 is not included in this release.
Fixture-only throughout: not an ATO, not a cATO, not a certification, not an
agency approval, and not a proof about arbitrary production integrations.

Background on where this came from: [docs/GENESIS.md](docs/GENESIS.md).
Release detail: [docs/RELEASE-v0.1.0.md](docs/RELEASE-v0.1.0.md).

Tillar Technologies LLC · Florida
