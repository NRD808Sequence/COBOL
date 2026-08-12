# Record layout

## The problem: three layouts, no spec

The course material contains three mutually incompatible descriptions of the
same policy record. No `POLICY.DAT` can satisfy all three, so before writing a
line of code you have to decide which one is authoritative — and that decision
is the first real act of legacy reconstruction in this lab.

**A. The course text** — `module3_60s/overview.md`

| Columns | Field |
|---|---|
| 1-6 | Policy number |
| 7-9 | Age |
| 10 | Vehicle code |
| 11-12 | Claims count |
| 13-18 | Base premium |

No state field. Age gets three columns. 18 bytes.

**B. `module4_LISP/lab2/cobol/cobol1.cob`** — 20 bytes

`9(6)` policy, `XX` state, `9(2)` age, `X` vehicle, `9(2)` claims,
`9(5)V99` premium.

**C. `module5_alienmoon/cobol/current.cob`** — 19 bytes

Identical to B except the premium narrows to `9(4)V99`.

## The decision: adopt B

Layout B is canonical here, for three reasons.

**The LISP capstone requires a state.** `module5_alienmoon/lisp/planning.lsp`
defines `marketing-priority` keyed on state:

```lisp
(setq high-value-states '(TX CA NY))
(defun marketing-priority (state claims) ...)
```

Layout A has no state field at all, so it cannot feed the capstone. A layout
that breaks a downstream consumer is not the intended one, whatever the prose
says.

**B is the superset.** It holds everything A holds plus state, and everything
C holds plus premium range. Choosing the widest declaration that satisfies
every consumer is the safe direction to be wrong in: an over-wide field
wastes columns, an under-wide one loses money silently.

**C's narrowing is the defect, not the spec.** `9(4)V99` caps a premium at
$9,999.99. Treating that as authoritative would bake defect 4 into the data
design. Captured proof that it is a defect is in
`../03_forensics/output-06-truncation.txt`.

This contradicts the Module 3 digest, which inherits layout A. The digest is
the one that needs reconciling.

## Canonical layout, 20 bytes

| Columns | Field | PIC | Notes |
|---|---|---|---|
| 1-6 | POL-NUM | `9(6)` | |
| 7-8 | STATE | `XX` | two-letter code |
| 9-10 | AGE | `9(2)` | |
| 11 | VEHICLE | `X` | S sedan, P sports, T truck |
| 12-13 | CLAIMS | `9(2)` | prior claims count |
| 14-20 | BASE-PREM | `9(5)V99` | implied decimal |

Vehicle codes are our reconstruction. The material names only "sports" (in
the PROLOG rule `vehicle(X, sports)`) and "sedan" (in the sample facts), and
never gives the single-character encoding. `P` is used for sports so it does
not collide with `S` for sedan.

## The implied decimal

`V` marks a decimal point that occupies no column. It is a property of how the
field is interpreted, not a character in the data.

```
$450.00      punched as   0045000       (00450 dollars, 00 cents)
$12,000.00   punched as   1200000
```

Punching a literal `.` is the most common way to destroy one of these files.
It consumes a column, shifts everything after it, and puts a non-digit into a
`PIC 9` field.

## Why fixed width matters

There are no delimiters. A field is defined solely by where it starts and how
long it is. Nothing in the record announces where the premium begins — the
`FD` in the program is the only description of the data that exists, which is
why the copybook and the file are useless apart from each other.

That is also why a one-column shift is catastrophic and silent: every field
after the shift point is still *readable*, just wrong. See
`../03_forensics/output-03-loopfix-columnshift.txt`, where a single stray
newline turns six policies into eleven plausible-looking bills.

## The decks

`POLICY.DAT` — the frozen six-record deck. Every branch of the renewal rule
fires at least once, and two records are claim-free so the defect's hiding
place is visible.

| Policy | State | Age | Veh | Claims | Base | Correct renewal |
|---|---|---|---|---|---|---|
| 100001 | TX | 34 | S | 0 | 450.00 | 450.00 |
| 100002 | CA | 62 | S | 0 | 520.00 | 545.00 |
| 100003 | NY | 41 | T | 2 | 600.00 | 700.00 |
| 100004 | TX | 58 | S | 3 | 750.00 | 925.00 |
| 100005 | FL | 22 | P | 1 | 380.00 | 430.00 |
| 100006 | OH | 67 | S | 4 | 900.00 | 1125.00 |

Batch total 4175.00, confirmed by captured output. This deck is **frozen**:
the $2,680 under-billing figure derived from it is already cited in the vault
notes, so adding records here would force a restatement. New scenarios get
their own file.

`POLICY-WORKED-EXAMPLE.DAT` — one record, policy 100007: base $1,000.00, age
60, 2 claims. This is the exact policy the vault's Bug Diff Analysis uses in
prose; running it turns that hand-computed table into a cited one.

`POLICY-TRUNCATION.DAT` — one record, policy 100008, base $12,000.00, no
claims, age 45. Nothing in the frozen deck reaches $10,000, so without this
file defect 4 stays theoretical.

Records 100005 (age 22, sports) and 100006 (4 claims) satisfy the two
`high_risk/1` clauses in `module4_LISP/lab4/prolog/sample1`, so this deck
feeds the PROLOG layer later without rework.

## `.DAT` versus `.CARD`

The `.DAT` files are newline-delimited so they stay hand-editable. A real 1964
deck has no delimiters — six 20-column records is 120 contiguous bytes.
`capture.sh` derives the `.CARD` images with `tr -d '\n'` at run time, so the
two forms cannot drift apart, and the difference between them is itself one of
the experiments.
