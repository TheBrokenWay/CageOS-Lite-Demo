# PredX Lessons for CageTutor Lite

This project is not Predator-X. It is lower-risk because it is a tutor and
research aid, not a pharmaceutical decision platform. The control philosophy is
still inherited from PredX: deterministic information, hidden enforcement, and
fail-closed boundaries.

## What PredX Teaches

1. Prompt rules are not security.
   A model can be instructed not to inspect gates, but that does not stop it
   from reading, summarizing, inferring, or socially engineering access to them.

2. Import restrictions are not enough.
   A Python module that cannot import gate code can still read files if the
   process has filesystem visibility. CageTutor therefore needs a separate
   tutor-visible side, not just import discipline.

3. The verifier side must be unseen.
   PredX Zone B keeps verifier tests, vault state, keeper envelopes, and hidden
   reasons outside the development identity. CageTutor Lite mirrors that with:
   Side A = tutor-visible runtime surface, Side B = hidden enforcement plane.

4. No LLM belongs in the verdict path.
   LLMs may explain, tutor, or summarize visible material. They do not decide
   pass/block/certify. Verdicts come from deterministic predicates and integer
   frames.

5. External input is untrusted.
   Natural language, screenshots, documents, and UI text enter through an edge
   converter. The governed core receives Math-X/QFrame codes, not raw external
   text.

6. Hidden reasons stay hidden.
   PredX handshake failures give agents a procedure reminder, while the real
   diagnostic goes to verifier-owned audit. CageTutor should render only safe
   verdicts to the tutor and keep detailed gate evidence in Side B.

7. Fail closed on missing prerequisites.
   Missing course scope, missing source context, missing manifest state, or
   invalid converted input must block or redirect. Do not invent defaults that
   make the system look green.

8. Claims must be tied to receipts.
   Verification counts, red-team status, replay status, and quality status must
   be produced by scripts and tests, not by assistant memory or prose.

9. Quality gates run last.
   The cycle ends with Ruff and Pyright so the final signal is professional
   cleanliness and strict typing after functional tests pass.

10. Immutability is a deployment step.
    During construction, gates remain editable. At seal time, Side B should be
    moved behind filesystem ownership or packaging that the tutor identity
    cannot read or modify. Side A is the only materialized surface given to the
    tutor agent.

## CageTutor Lite Mapping

| PredX concept | CageTutor Lite mapping |
| --- | --- |
| Zone A development workspace | Build repo while constructing CageTutor |
| Zone B verifier/vault | Hidden Side B enforcement plane |
| Edge converter | `converters/text_converter.py` |
| Math-X substrate | `qframe.py` and integer codebook |
| Sentinel | `sentinel_lite.py` |
| Boundary scanner | `boundary_lite.py` |
| Keeper quorum | `keeper_lite.py` |
| Watchdog/TestDog style checks | `watchdog_lite.py`, red-team fixtures, replay tests |
| Agent procedure warning | tutor-safe rendered verdicts |
| Hidden verifier diagnostics | Side B audit and gate evidence |

## Seal Target

When development is complete, the tutor process should start with:

- no repository-wide file access
- no Side B source files present in its workspace
- no gate code, tests, red-team fixtures, manifests, or build files visible
- only Side A contract files and rendered gate outputs available
- all pass/block decisions produced before the tutor model sees the task

This is the reason for the Side A materialization test. The correct final
deployment model is not "the tutor can see the gates but cannot import them."
It is "the tutor cannot see the gates at all."
