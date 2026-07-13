# CageOS Lite Demo

Public demonstration of the CageOS Lite control pattern.

This repository is intentionally small. It is meant to show the public-facing
surface of a governed system without exposing the hidden enforcement plane that
actually controls behavior.

The core idea is simple:

> capable models and tools should not be trusted as their own governors.
> Governance should remain outside the model, outside the visible workspace,
> and inside an independent control layer.

## Genesis

This demo makes more sense if you understand where it came from.

The original pressure was not "build a tutoring demo." The original pressure
was scientific and pharmaceutical decision support in a high-consequence
setting. That work led to a hard conclusion:

- better answers were not enough
- prompting alone was not enough
- review after the fact was not enough

What was needed was a governed operating path where the model did not control
its own boundaries.

That realization produced a wider split:

- **PredX** remained the scientific product line
- **CageOS** became the governance substrate
- **CageOS Lite** became the smallest public proof that the governance pattern
  could be demonstrated without exposing the private control plane

This repository exists to show that genesis in public form.

## What this demonstrates

- Side A / Side B separation
- a tutor-visible contract surface
- bounded, governed agent behavior
- the principle that LLMs should not decide pass/block outcomes
- the principle that enforcement internals should be unseen by the system being
  governed
- a modular public proof point for the broader CageOS product family

## Why this matters

Most AI systems rely on one of two weak patterns:

1. prompt-only restraint
2. advisory review after the fact

CageOS Lite demonstrates a different pattern:

- the governed system sees only the visible work surface
- the enforcement plane is separate
- decisions can be routed, blocked, escalated, or constrained without giving
  the model direct access to the control internals

This treats governance as an operating-path problem, not a wording problem.

## Public proof claim

This demo is designed to support one specific claim:

> governance can remain outside the model while still shaping what the model is
> allowed to do.

In the broader CageOS family, the same design direction is intended to govern
other LLM and program workflows beyond tutoring.

## What this repository demonstrates about the process

This repository is not just a demo of a result. It is a demo of a design
decision:

1. start from a high-trust problem
2. discover that the model cannot be the final governor of that problem
3. move governance outside the model
4. expose only the proof surface publicly

That process is the genesis of the CageOS family.

## What is intentionally not public

This repository does not include:

- production gate source
- hidden red-team fixtures
- replay verification internals
- private school/course data
- PredX or full CageOS internals
- operational sealing scripts
- real bypass/evasion catalogs
- trade-secret enforcement details

That omission is deliberate. The public value is the control pattern and proof
surface, not the internal method disclosure.

## Repository layout

```text
src/cagetutor/agent/      tutor-visible contract surface
docs/                     public explanatory notes
README.md                 public demonstration overview
```

## Read this next

- [Public demonstration page](docs/index.md)
- [Genesis and product-family path](docs/GENESIS.md)
- [PredX lessons for CageTutor](docs/PREDX_LESSONS_FOR_CAGETUTOR.md)

## Core design principle

The tutor agent should see rendered task instructions and rendered gate
verdicts. It should not see the enforcement implementation. A capable LLM will
try to inspect, infer, or route around rules if the rules are visible in its
workspace. CageOS Lite treats that as a deployment-boundary problem, not a
prompting problem.

## Product-family context

CageOS Lite is the public demonstration edge of a wider governed-systems family:

- CageOS for bounded operational governance
- CageOS Lite for governed tutoring and guided learning workflows
- PredX as a governed scientific decisioning product line

This repository only proves the CageOS Lite public pattern. It is not intended
to expose the full internal product stack.
