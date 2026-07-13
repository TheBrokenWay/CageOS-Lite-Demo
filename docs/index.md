# CageOS Lite Demo

Public proof of the CageOS Lite control pattern.

This page is intentionally narrow. It explains what the demo proves without
publishing the hidden enforcement logic.

## One-sentence claim

CageOS Lite demonstrates that a capable model can be made to operate inside a
bounded, reviewable surface while the actual governance remains outside the
model's visible workspace.

## What the demo proves

- the model-facing surface can be separated from the governance plane
- the governed agent does not need visibility into the enforcement internals
- pass, block, redirect, and escalation behavior can be structured as system
  outcomes rather than model self-policing
- public demonstration does not require public release of the private control
  path

## What this is not

This is not:

- a dump of production internals
- a jailbreak catalog
- a full CageOS release
- the complete PredX stack
- a claim that prompting alone creates governance

## Architecture idea

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

A sufficiently capable model will inspect, infer, and route around visible
constraints if the constraints are placed in the same surface it controls.

CageOS Lite treats that as a deployment and boundary problem:

- keep the visible working surface narrow
- keep the enforcement surface separate
- keep the decision authority outside the model

## Public scope

This repo intentionally keeps the public scope small:

- a tutor-visible contract
- a minimal reference surface
- explanatory documentation

It intentionally excludes:

- production gate logic
- replay and red-team internals
- private data
- sealed operational procedures
- trade-secret implementation details

## Why the repository is small

If the goal were only to look busy, this repository would be larger.

The goal is different:

show the control pattern clearly without teaching outsiders how the private
enforcement plane works.

## Read next

- [Repository README](../README.md)
- [PredX lessons for CageTutor](PREDX_LESSONS_FOR_CAGETUTOR.md)
