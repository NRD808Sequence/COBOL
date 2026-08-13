# Vault evidence handback

Everything the 2026-08-11 handoff asked for, mapped to the checkbox it fills.
Paths are relative to this directory unless noted.

Captured on `macos-docker` and `proxmox-debian`, GnuCOBOL 3.1.2.0,
`-x -std=cobol85 -Wall`. All six `output-*.txt` files are byte-identical
across the two hosts; see `env-macos-docker.txt` and `env-proxmox-debian.txt`
for the provenance that is allowed to differ.

## `docs/COBOL Bug Diff Analysis` — "Evidence to generate"

| Checkbox | Artifact | Result |
|---|---|---|
| Console output of both programs on the same sample policies | `output-04-multiply-bug.txt` | Both run over the same 6-record card image |
| Diff table of intended vs buggy premiums with dollar deltas | `BUG-REPORT.md`, "Defect 3" | Batch: 1495.00 vs 4175.00, delta **-2680.00** |
| The GnuCOBOL compile error on the invalid `ADD ... * 50` | `output-02-current-asis.txt` | `error: syntax error, unexpected *, expecting GIVING` |
| The corrected `COMPUTE` version compiling and producing right totals | `output-04-multiply-bug.txt` | `RECORDS 0006 TOTAL 4175.00` |

The doc's worked example is now backed by a real run rather than hand
arithmetic. `output-05-worked-example.txt`, policy 100007, base $1,000.00,
age 60, 2 claims: buggy **100.00**, correct **1125.00**, delta **-1025.00**.
That matches the figure already in the doc, so no restatement is needed.

## `docs/Modernization Bridge Runbook (Proxmox Lab)` — Stage 1

| Step | Artifact | Status |
|---|---|---|
| Hand-craft a fixed-width `POLICY.DAT` | `../01_record_layout/POLICY.DAT` + `LAYOUT.md` | Done, 6 records, 20 bytes each |
| Compile and run both programs, capture console output | `output-01-asis.txt`, `output-02-current-asis.txt` | Done — **neither original runs** |
| Show the compile error, fix with `COMPUTE` | `output-02-current-asis.txt`, `RENEWAL-04-CORRECT.cob` | Done |
| Intended-vs-buggy dollar-delta table | `BUG-REPORT.md` | Done |
| Environment: VMID, bridge, IP, Tailscale hostname | `../00_environment/ENV.md` | Done — VMID `101`, bridge `vmbr0`, IP `172.16.25.89`, Tailscale hostname n/a (subnet route) |

## Three corrections for the vault text

**1. `current.cob` is not "the fixed version."** The doc frames the two
programs as buggy and fixed. Neither works. `current.cob` fails to compile,
and it also *introduces* a defect the earlier version did not have by
narrowing `BASE-PREM` from `9(5)V99` to `9(4)V99`. The accurate framing is
two successive drafts, neither ever compiled — which is a stronger version of
the same story.

**2. Two defects were missing from the digest, and a third is new.** The
handoff already folded in the `OPEN`-in-loop crash and the truncation
narrowing. The narrowing turns out to do more damage than expected: shortening
the record from 20 to 19 bytes makes the batch read a **phantom seventh
policy** off the leftover byte and bill it. One input card, two output bills.
See `output-06-truncation.txt`.

**3. The column-shift answer is now empirical.** `output-03-loopfix-columnshift.txt`
runs one binary against the same six records in two physical formats. With
newlines, six policies become eleven output lines billing $17,500.00,
$2,300.00, $900.00, $4,100.00 and $6,700.00 against policy numbers that were
never on a card. No crash, no warning, exit code 0. This is the concrete
answer to the final lab's "what happens if this shifts one column left?"

## Needs a doc edit, not a paste

`../01_record_layout/LAYOUT.md` **contradicts** `modules/Module 3 — 1960s
Insurance Batch Scenario`. The digest inherits the instructor's column map
(1-6 policy, 7-9 age, 10 vehicle, 11-12 claims, 13-18 premium, no state). The
lab adopts the 20-byte layout from `cobol1.cob` instead, because
`planning.lsp` keys `marketing-priority` on state and a stateless layout
cannot feed the capstone.

Three layouts exist in the material and at most one can be right. `LAYOUT.md`
lays out the argument; the Module 3 digest needs a reconciliation note rather
than a copy-paste.

## For the Portfolio Narrative and STAR docs

The reusable line: a 69-line program with four defects, of which only one
announces itself. The compile error is found in a second. The runtime abort is
found in a minute. The $2,680 under-billing is invisible without knowing the
business rule, because it produces a well-formed dollar amount and leaves
claim-free policies untouched — and most policies are claim-free.

Reproduce anything here with `cd lab && make verify`. That target asserts
every headline figure, so the write-ups cannot drift from the evidence
without the build going red.
