# CageOS Lite — what is proven, and what is not

Read this before you read anything else we say about CageOS. A control must
never claim more than the property it actually checks, so this file states the
boundaries in plain English and then shows the measurements behind them.

## The three separations

**1. A valid release signature proves that Tillar Technologies signed this
specific release manifest.** It does not prove that the software's runtime
claims are true. It proves *which software you have*, nothing more.

Signing uses the GPG key adopted for this project on 2026-08-25, pinned by
full fingerprint `CD62DA5B5F9F3E694C1D5536A182E6E145D573FB`. Verification
requires `gpg` or `gpgv`; without one the driver refuses to execute the engine
rather than falling back to a weaker check. We do not reimplement OpenPGP to
avoid that dependency — doing so would turn a solved signing problem into new
security-critical code.

**Stated plainly rather than dressed up: that signing key lives in the
keyring of a networked developer workstation.** It is not on an air-gapped
machine and not in a hardware token, and we are not going to describe it as if
it were. What a signature therefore establishes is that the release came from
that key. If the workstation is compromised, so is the signing identity, and
the honest mitigation is fingerprint publication in two independent places
(this repository and tillartechnologies.com) so a substituted identity is
visible rather than silent.

**2. Runtime claims are evaluated separately**, by the independent verifier,
against externally observable state. The engine's own `execution`,
`observation` and `reconciliation` fields are treated as **claims**, never as
findings. The verifier creates the demo root, seeds the refusal target itself,
records the state before the engine is permitted to run, and reads the state
again afterwards. Where the record and the world disagree, the verifier sides
with the world.

**3. The Lite demonstration proves the bounded scenarios shipped with this
release.** It is not an ATO, not a cATO, not a certification, not an agency
approval, not a general host-integrity proof, and not a proof about arbitrary
production integrations. It is fixture-only throughout.

Authentic software, authentic evidence, and independently observed reality are
three different things. Keeping them apart is the point.

## What the guarantee does not cover

The guarantee ends at the host. A hostile administrator can act outside the
CageOS path. Local state and a local witness configuration can be rolled back
together. No independently operated off-host witness is accepted yet.
Post-reboot persistence is unmeasured. Production emission remains locked.

## The eight gates, and what each one establishes

Run them yourself: `./gates.sh <release-dir>`. Six are attacks that must be
rejected; two are legitimate runs that must pass. A control that cannot fail
has not been tested, so every attack is paired with the legitimate case it
inverts.

| # | Gate | Establishes |
|---|---|---|
| 1 | Release substitution | One flipped byte in the engine and the driver refuses **before execution** |
| 2 | Manifest forgery | Recomputing hashes without the offline key fails the signature |
| 3 | Evidence forgery | A **internally flawless** bundle still loses to observed reality |
| 4 | Replay | An old genuine transcript cannot answer a fresh challenge |
| 5 | False success | A claimed authorized effect that did not happen is contradicted by the filesystem |
| 6 | False refusal | A claimed refusal that did happen is contradicted by pre/post state |
| 7 | Idempotency | A re-presented authorization returns the same decision key, no second decision |
| 8 | Clean run | Everything passes from a fresh directory |

**Gate 3 is the one that matters most.** In that run the forged evidence
bundle was internally perfect: every digest matched the bytes on disk, every
record was bound to the run's challenge, the schema conformed, and the
decision key was present. It failed anyway, on three checks that are
observations of reality rather than of the bundle. That is the whole claim:

> The record is not privileged. When the record and the world disagree, the
> verifier sides with the world.

## Measured limitation: the disposable scenarios

Four of the six scenarios use the **disposable** scratch capability, whose
cleanup guard removes the artifact by design. For those, an empty directory is
*not* evidence of refusal — an authorized action also ends with an empty
directory. The verifier is told this explicitly rather than left to infer a
distinction the filesystem cannot support, and it applies the "left nothing
behind" check only where it is meaningful.

The two **persistent** scenarios exist precisely to close that gap. They use a
separate authority type, `RetainedWriteCapability`, whose durability is a
property of the type rather than a flag: the disposable capability owns a
cleanup guard and the retained one does not. Nothing about the existing
containment guarantee was weakened to make the demo work.

## Failures found during development, preserved on purpose

These are kept because a demonstration that has never been wrong is a
demonstration nobody has tested.

**Replay semantics were corrected by execution.** The demo first asserted that
a replayed authorization would be *refused*. Running it proved otherwise: no
second decision is ever minted, and the already-durable decision is returned
under the same key, marked `recovered`. The real behavior is better than the
claim, and shipping the claim would have shipped a falsehood.

**"Written" was caught as false by the verifier.** The engine claimed a target
state of `WRITTEN`; the bounded capability's cleanup guard had already removed
the artifact. Our own verifier caught our own engine overstating a result.

**A seemingly valid evidence system was broken before publication.** Three
forgeries were run against an earlier verifier. Two were caught. The third —
self-consistent, manifest recomputed, decision key fabricated — passed every
check. That finding is why release signing and independent observation of
external state both exist here, and why neither is presented as sufficient
alone.

**"Empty" was the wrong refusal property.** For the persistent scenario the
property that actually holds is *byte-for-byte unchanged*, and the seeded
baseline had to move from the engine to the verifier, because a baseline the
engine chose would let the engine define what "unchanged" means.

## Assumption failures during release engineering, recorded on purpose

Two of these are the exact class CageOS exists to eliminate: a plausible
narrative silently substituting itself for measured state.

**An offline signing machine was specified that had never been established to
exist.** The ceremony was written first and the substrate assumed afterwards.
The same project had already recorded this pattern once, when "tmpfs is
RAM-only" turned out to be false under WSL2's disk-backed swap.

**A parallel signing mechanism was invented although one had already been
adopted.** GPG was ruled ADOPT on 2026-08-25, with a real key measured against
four adversarial cases. A separate Ed25519 release-signing scheme was built
anyway, and a custom OpenPGP verifier was then started to preserve the phrase
"zero dependency" — which would have replaced a solved problem with new
security-critical code. It was stopped before it shipped and deleted.

Both were caught by review rather than by testing, which is worth noting: the
gates in this file would not have caught either one, because both produced
systems that passed their own checks.

## Release-engineering findings, second-machine test

Recorded because they are conditions a real customer will meet.

**The artifact is statically linked, and that is not cosmetic.** The first
package built with the default toolchain embedded a Nix store path as its ELF
interpreter and required glibc 2.39. On a second machine with glibc 2.28 it
could not start at all — the error is "No such file or directory" from a
missing loader, which looks like a missing file and is not. The release is now
built for `x86_64-unknown-linux-musl`, and the packaging script refuses to
ship any binary that still declares a program interpreter.

**The enforcement daemon ships with the release.** The engine drives the
lifecycle as a real subprocess; that process boundary is a property being
demonstrated, not an implementation detail. Packaging without it failed three
of the eight gates. Its hash is in the signed manifest and the driver refuses
a substituted daemon exactly as it refuses a substituted engine.

**`/tmp` is often mounted `noexec`.** On the shared host used for the
second-machine test it is, so the artifact must be extracted somewhere
executable — a home directory works. This is a hosting convention, not a
CageOS constraint, and it is documented rather than worked around.

**Python 3.6 is enough.** The tooling originally used `subprocess`
`capture_output=` and `text=` (3.7+) and `copytree(dirs_exist_ok=)` (3.8+).
An evaluator on an older interpreter should not have to upgrade Python before
being allowed to check our claims, so the tooling was lowered rather than the
requirement raised. Everything else — Ed25519 verification, hash checks,
challenge generation, state capture — already worked unchanged on 3.6.8.
