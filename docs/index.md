# CageOS Lite Demo

Public proof of the CageOS Lite control pattern.

This page is intentionally narrow. It explains what the demo proves without
publishing the hidden enforcement logic.

## One-sentence claim

CageOS Lite is a signed fixture proof: a closed engine runs the scenarios
shipped with the release, and an open verifier checks the engine's claims
against the filesystem on the same machine. A clean run is 58 of 58 checks
and 8 of 8 gates. No language model is loaded, called, or supervised.

## Genesis in one page

The public demo came last, not first.

The work began with a scientific decision-support problem: how to use capable
systems in high-consequence settings without treating the model as trustworthy
enough to govern itself. That led to a broader systems conclusion:

- the model should do work
- the model should not define its own boundary conditions
- governance has to live in an independent control layer

From that point the project separated into roles:

- **PredX** for the scientific domain objective
- **CageOS** for the governance substrate
- **CageOS Lite** for the public proof surface

This page exists to explain that final layer without disclosing the private
mechanics underneath it.

## What the demo proves

On one Linux x86_64 host, for the fixture scenarios in the signed release:

- an authorized persistent write is observed by the verifier, which reads the
  file after the engine exits
- a refused persistent target is byte-for-byte unchanged
- a false success and a false refusal are contradicted by the filesystem
- a tampered release is refused before the engine runs
- the public verifier can show that without publishing the private engine

An independently operated witness on a separate machine is not part of this
release. The runnable steps are in the [repository README](../README.md).
`./quickstart.sh` is the first command.

## What this is not

This repository is not:

- a supervisor for a live language-model agent
- a production deployment, an ATO, a cATO, or a certification
- a dump of production internals
- a jailbreak catalog
- a full CageOS release
- the complete PredX stack
- a claim that prompting alone creates governance

## Architecture idea

The diagram below is the product-family aim: a visible working surface and a
separate enforcement plane. The signed demo does not run that surface. It runs
fixture scenarios and checks them from outside the engine.

```text
User / Operator
      |
      v
Visible agent surface (Side A)
      |
      v
Governed outcomes: allow / redirect / escalate / block
      ^
      |
Hidden enforcement plane (Side B)
```

The key design choice is that the agent-facing layer and the enforcement layer
are not the same thing.

## Why this pattern exists

The family was aimed at a deployment boundary: a sufficiently capable model
will inspect, infer, and route around visible constraints if the constraints
sit in the same surface it controls. The runnable proof in this repository is
the fixture verifier described above. The aim itself is:

- keep the visible working surface narrow
- keep the enforcement surface separate
- keep the decision authority outside the model

## Why the public material is intentionally incomplete

This public repo is designed to prove the direction of the system, not to teach
outsiders how the private enforcement path works.

That means the repository is optimized for:

- clarity of the governance thesis
- visible product genesis
- safe proof of the control pattern

It is not optimized for:

- full implementation disclosure
- operational reproduction of private controls
- release of trade-secret governance mechanics

## Public scope

The runnable public surface is the signed release plus the verifier and the
eight gates. `./quickstart.sh` downloads that release and runs it.

Also in the tree, and not part of that proof: `src/cagetutor/` and
`docs/PREDX_LESSONS_FOR_CAGETUTOR.md`, an early sketch of a tutor-agent
contract. The verifier does not import them, and they are not in the signed
tarball.

The repository keeps private:

- the engine and daemon source
- sealed operational procedures
- trade-secret implementation details

## Why the repository is small

If the goal were only to look busy, this repository would be larger.

The goal is different:

show the control pattern clearly without teaching outsiders how the private
enforcement plane works.

## Read next

- [Repository README](../README.md)
- [Genesis and product-family path](GENESIS.md)
- [PredX lessons for CageTutor](PREDX_LESSONS_FOR_CAGETUTOR.md)
