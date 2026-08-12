# lab — 1964 insurance renewal batch

Working tree for the course. The instructor's `module*/` trees are read-only
evidence; everything here is ours.

```sh
make forensics   # compile and run the ladder, write 03_forensics/
make verify      # assert every headline figure still reproduces
```

## What is here

```
00_environment/  Dockerfile (pinned), capture.sh, ENV.md, SMOKE.cob
01_record_layout/  LAYOUT.md, card-template.txt, three decks
02_cobol/          the five-program bisect ladder
03_forensics/      BUG-REPORT.md, VAULT-EVIDENCE.md, captured output
```

## The ladder

Two of the instructor's five code files are COBOL, and neither one runs. Each
program below differs from its neighbour by exactly one change, so every
captured artifact isolates a single variable.

| Program | Change from previous | Outcome |
|---|---|---|
| `RENEWAL-01-ASIS` | `cobol1.cob` verbatim | Compiles, aborts on record 2 |
| `RENEWAL-02-CURRENT-ASIS` | `current.cob` verbatim | Does not compile |
| `RENEWAL-03-LOOPFIX` | hoist `OPEN` out of the loop | Runs, under-bills by $2,680 |
| `RENEWAL-04-CORRECT` | `COMPUTE` instead of `GIVING` | Correct: 4175.00 |
| `RENEWAL-05-NARROW` | `9(5)V99` narrowed to `9(4)V99` | 10x error plus a phantom bill |

Findings are written up in [03_forensics/BUG-REPORT.md](03_forensics/BUG-REPORT.md).

## What happens if this shifts one column left

The final lab asks this and says that answering it calmly means you have
succeeded. The calm answer is that **nothing happens** — and that is the
problem.

A one-column shift produces no crash, no warning, and exit code 0. Every field
after the shift point is still readable, and reading is all the program does.
The output is well-formed, plausible, and fictional.

Run one binary against the same six policies in two physical formats — a
120-byte card image, then the same records with newlines added — and the
second run turns six policies into eleven bills for $17,500.00, $2,300.00,
$900.00, $4,100.00 and $6,700.00 against policy numbers that were never on a
card. Captured in
[03_forensics/output-03-loopfix-columnshift.txt](03_forensics/output-03-loopfix-columnshift.txt).

Nothing in a fixed-width record announces where a field begins. The `FD` in
the program is the only description of the data that exists, which is why a
copybook and its file are worthless apart from each other, and why the newline
— not the COBOL — is the anachronism.

## The layered reading

The course's own frame, and where each layer lives here.

| Layer | 1960s form | In this lab |
|---|---|---|
| 1 — Data representation | Punch cards, 80 columns | [01_record_layout/](01_record_layout/) |
| 2 — Deterministic processing | COBOL batch | [02_cobol/](02_cobol/) |
| 3 — Rule reasoning | Early expert systems | PROLOG underwriting — not yet built |

Layer 3 is deliberately out of scope for this pass. The deck already carries
the records that exercise it: policy 100005 (age 22, sports) and 100006 (4
claims) satisfy the two `high_risk/1` clauses in
`../module4_LISP/lab4/prolog/sample1`, so the rule base can be added without
touching the data.

## Coursework this covers

- Module 2 Lab 1 — compile a `DISPLAY` program: `00_environment/SMOKE.cob`
- Module 2 Lab 7 — sequential file processing with `READ` / `AT END`
- Module 2 Lab 8 — full batch processor: input file, output file, totals,
  modular paragraphs (`RENEWAL-04-CORRECT.cob` writes `BILLING.RPT`)
- Module 2 final lab — the one-column question, above
- Module 3 Week 1 — record layout design: [01_record_layout/LAYOUT.md](01_record_layout/LAYOUT.md)
- Module 3 Week 2 — the renewal premium batch

## Reproducibility

Docker is the canonical runner so that the macOS capture and a later Proxmox
capture produce byte-identical `output-*.txt`. Toolchain detail that
legitimately varies by host goes to `env-*.txt` instead. Details and the
outstanding Proxmox fields are in
[00_environment/ENV.md](00_environment/ENV.md).
