# CageOS Lite v0.1.0 — release notes

**Linux x86_64 / static musl. Signed by Tillar Technologies. 58/58
verification, 8/8 adversarial gates, validated on a second machine.**

```
Archive:         cageos-lite-0.1.0.tgz
Archive SHA-256: 7a671ed54ec3337e1b65a02c9c46ec5cb2c67225931fae1d3a6e7407f256a1d9
Release signer:  CD62DA5B5F9F3E694C1D5536A182E6E145D573FB
Platform:        linux-x86_64, ELF, static-musl
```

## What it is

A closed enforcement engine that runs a real, fixture-only CageOS lifecycle,
and a public verifier that does not trust it. The verifier checks the release
signature, checks the engine and daemon hashes against the signed manifest,
chooses a random challenge, runs that exact binary, then reads the real
filesystem and compares every claim against what it finds.

## The centerpiece: gate 3

A completely self-consistent forged evidence bundle still fails.

In that run the forgery is internally flawless — every digest matches the
bytes on disk, every record is bound to the run's challenge, the schema
conforms, the decision key is present. It fails on checks that observe reality
rather than the bundle:

```
ENGINE CLAIM  decision=AUTHORIZED execution=OK observation=MATCH reconciliation=COMMITTED
  *** FAIL ***  [05] OBSERVED: the expected target exists
  *** FAIL ***  [05] CLAIM == REALITY   THE ENGINE'S SUCCESS CLAIM IS CONTRADICTED BY THE FILESYSTEM
```

**The record is not privileged. When the record and the world disagree, the
verifier sides with the world.**

## Verification results

| Stage | Build machine | Second machine |
|---|---|---|
| Release signature (pinned full fingerprint) | PASS | PASS |
| Six signed artifact hashes | PASS | PASS |
| Both binaries static, zero interpreters | PASS | PASS |
| Independent verification | 58/58 | 58/58 |
| Adversarial gates | 8/8 | 8/8 |
| Payload digest unchanged by testing | — | PASS |

The second machine is a separate x86_64 host (glibc 2.28, Python 3.6.8, gpgv
2.2.20). It did not merely confirm the archive arrived intact; it rebuilt the
whole chain from the extracted package — verified the signature with the
packaged key, recomputed every manifest-named hash locally, confirmed both ELF
binaries carry no program interpreter, ran the customer entrypoint, ran the
adversarial matrix, and took a payload digest **before and after** testing to
prove the tests themselves altered nothing.

## What release signing establishes, and what it does not

- **A valid signature proves Tillar Technologies signed this release
  manifest.** It proves which software you have. It does not prove the
  software's runtime claims are true.
- **Independent observation proves whether the effect matched the claim.** It
  is done by the verifier in this repository, against externally observable
  state, not by the engine.
- **Neither proves** production readiness, ATO, cATO, certification, agency
  approval, general host integrity, or anything about arbitrary production
  integrations.

The signing key lives in the keyring of a networked developer workstation. It
is not on an air-gapped machine and not in a hardware token, and we are not
going to describe it as if it were. Fingerprint publication in two independent
places is the honest mitigation. Full detail in
[LIMITS.md](../LIMITS.md).

## Engineering history — what development actually caught

Kept because a demonstration that has never been wrong is one nobody has
tested. Each of these was a real defect found before publication:

1. **False replay semantics.** The demo asserted a replayed authorization
   would be refused. It is not: no second decision is minted, and the
   already-durable decision returns under the same key, marked recovered. The
   real behavior was better than the claim — and the claim would have shipped
   a falsehood.
2. **A false "written" claim.** The engine reported a target state the
   filesystem contradicted, because the bounded capability disposes of its own
   artifact by design. Our own verifier caught our own engine.
3. **Forgeable evidence.** An earlier verifier passed a self-consistent forged
   bundle. That finding is why release signing and independent observation of
   external state both exist here, and why neither is offered as sufficient
   alone.
4. **A binary that could not execute.** Built with the development toolchain,
   it embedded a build-machine store path as its ELF interpreter. The failure
   reads "No such file or directory" — a missing loader that looks like a
   missing file.
5. **glibc portability.** The first build required glibc 2.39 and would have
   silently excluded older enterprise systems.
6. **Missing daemon packaging.** The engine drives the lifecycle as a real
   subprocess; that boundary is a security property, not packaging debris.
   Shipping without it failed three of the eight gates.
7. **`noexec /tmp`.** A condition common on shared hosts that a developer
   workstation never shows you.
8. **Two bad signing assumptions.** An offline signing machine was specified
   that had never been established to exist, and a parallel signing scheme was
   invented although one had already been adopted and measured. Worth stating
   plainly: **the eight gates would have caught neither**, because both
   produced systems that passed their own checks. Review caught them.

## Reproducing our result

```bash
sha256sum cageos-lite-0.1.0.tgz     # expect the archive digest above
tar xzf cageos-lite-0.1.0.tgz && cd cageos-lite-0.1.0-rc
gpgv --keyring ./tillar-release-key.gpg RELEASE.manifest.sig RELEASE.manifest
sha256sum -c <<<"$(grep engine_sha256 RELEASE.manifest | cut -d= -f2)  cageos-lite"
readelf -l cageos-lite | grep -c 'program interpreter'   # expect 0
python3 run_demo.py .                                     # expect 58/58
./gates.sh .                                              # expect 8/8
```

The archive is transport only; the signed object is `RELEASE.manifest` and the
files it authenticates. No second signature is introduced for the archive, and
the archive is not recreated now that its digest is published.
