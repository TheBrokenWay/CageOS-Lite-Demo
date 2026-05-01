# CageOS Lite Demo

This repository is a public demonstration of the CageOS Lite pattern.

It intentionally does not include the hidden enforcement plane. The full local
build keeps gate code, red-team fixtures, replay checks, QFrame substrate,
policy internals, and release tests in a private Side B.

## What This Demo Shows

- Side A / Side B separation.
- A tutor-visible contract.
- The principle that LLMs should not decide pass/block outcomes.
- The principle that gate internals should be unseen by the agent being
  governed.
- A reduced reference for discussing deterministic agent control.

## What This Demo Does Not Include

- Production gate source.
- Hidden red-team fixtures.
- Private school/course data.
- PredX or full CageOS internals.
- Operational sealing scripts.
- Real bypass/evasion catalogs.

## Core Idea

The tutor agent should see rendered task instructions and rendered gate
verdicts. It should not see the enforcement implementation. A capable LLM will
try to inspect, infer, or route around rules if the rules are visible in its
workspace. CageOS Lite treats that as a deployment-boundary problem, not a
prompting problem.
