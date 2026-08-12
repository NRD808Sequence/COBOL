# Bug report: the 1964 renewal batch

Four defects across two programs totalling 69 lines. Every figure below comes
from a captured run in this directory and is guarded by `make verify`.

The renewal rule the code is supposed to implement:

```
NEW PREMIUM = BASE PREMIUM + (25 if AGE > 50) + (50 per claim)
```

## Summary

| # | Defect | Where | Surfaces as | Evidence |
|---|---|---|---|---|
| 1 | Arithmetic expression inside `ADD` | `current.cob:33` | Compile error | `output-02-current-asis.txt` |
| 2 | `OPEN INPUT` inside the loop target | `cobol1.cob:21` | Runtime abort on record 2 | `output-01-asis.txt` |
| 3 | `MULTIPLY ... GIVING` overwrites the accumulator | `cobol1.cob:32` | Silent under-billing | `output-04-multiply-bug.txt` |
| 4 | `9(5)V99` narrowed to `9(4)V99` | `current.cob:16` | Silent 10x error plus a phantom bill | `output-06-truncation.txt` |

Neither program was ever compiled. Defect 1 stops the module 5 program at the
compiler, and defect 2 stops the module 4 program on its second record. That
is not a guess about process; it is what the compiler and the runtime say.

## Defect 1 — `ADD` does not take expressions

`module5_alienmoon/cobol/current.cob` line 33:

```cobol
003300         ADD CLAIMS * 50 TO NEW-PREM.
```

```
RENEWAL-02-CURRENT-ASIS.cob:33: error: syntax error, unexpected *, expecting GIVING
compile exit=1
```

`ADD` and `MULTIPLY` take operands, not expressions. The diagnostic is
precise about the alternative the grammar was willing to accept: `GIVING`.
The portable fix is `COMPUTE`:

```cobol
003300         COMPUTE NEW-PREM = NEW-PREM + (CLAIMS * 50).
```

This matters beyond the syntax. `current.cob` reads as the *corrected*
successor to `cobol1.cob` — someone saw that `MULTIPLY ... GIVING` was
destroying the total and reached for accumulation instead. They just reached
for a form that does not exist. The fix was right in intent and never once
run.

## Defect 2 — the file is re-opened every iteration

`module4_LISP/lab2/cobol/cobol1.cob`:

```cobol
002000 MAIN-LOOP.
002100     OPEN INPUT POLICY-FILE.
002200     READ POLICY-FILE
002300         AT END STOP RUN.
002400     PERFORM CALCULATE.
002500     DISPLAY POL-NUM NEW-PREM.
002600     GO TO MAIN-LOOP.
```

`GO TO MAIN-LOOP` re-enters the paragraph that contains the `OPEN`.

```
100001000450.00
libcob: error: file already open (status = 41) for file POLICY-FILE ('POLICY_DAT' => POLICY.DAT)
run exit=1
```

One policy billed out of six. This program cannot process a deck at all,
which makes it useless as a batch job and useful as evidence: `current.cob`
hoists the `OPEN` into `MAIN` and loops back to a separate `READ-REC` label
instead. The two files are successive drafts of one program, and this is the
bug that prompted the rewrite.

## Defect 3 — `GIVING` assigns, it does not accumulate

The headline defect, and the only one that produces a plausible wrong answer
instead of an error.

```cobol
002800     MOVE BASE-PREM TO NEW-PREM.
002900     IF AGE > 50
003000         ADD 25 TO NEW-PREM.
003100     IF CLAIMS > 0
003200         MULTIPLY CLAIMS BY 50 GIVING NEW-PREM.
```

`MULTIPLY CLAIMS BY 50 GIVING NEW-PREM` means `NEW-PREM = CLAIMS * 50`. The
base premium and the age surcharge computed on the three lines above are
discarded the instant a policy has a claim.

Both columns below are captured runs over the same card image, differing only
in that one line:

| Policy | Age | Claims | Base | Buggy | Correct | Delta |
|---|---|---|---|---|---|---|
| 100001 | 34 | 0 | 450.00 | 450.00 | 450.00 | 0.00 |
| 100002 | 62 | 0 | 520.00 | 545.00 | 545.00 | 0.00 |
| 100003 | 41 | 2 | 600.00 | 100.00 | 700.00 | -600.00 |
| 100004 | 58 | 3 | 750.00 | 150.00 | 925.00 | -775.00 |
| 100005 | 22 | 1 | 380.00 | 50.00 | 430.00 | -380.00 |
| 100006 | 67 | 4 | 900.00 | 200.00 | 1125.00 | -925.00 |
| | | | | **1495.00** | **4175.00** | **-2680.00** |

The batch under-bills by **$2,680.00**, or 64% of the premium it should have
collected.

### Why this survives for decades

Look at policies 100001 and 100002. Both produce an **identical** figure under
the buggy and the corrected program, because the defect only fires when
`CLAIMS > 0`.

In a real book of business the large majority of policies are claim-free in
any given year. So the defect is invisible on most records, and on the records
where it does fire it produces a well-formed dollar amount rather than a
crash. There is no error, no warning, no failed reconciliation — the batch
"ran successfully" every month.

Catching it requires knowing what the premium was *supposed* to be. No amount
of reading the code more carefully will tell you, because the code is
self-consistent. That is the whole skill the course is teaching.

The worked single-policy case in `output-05-worked-example.txt`: base
$1,000.00, age 60, 2 claims. Intended 1000.00 + 25.00 + 100.00 = **1125.00**.
Buggy 2 x 50 = **100.00**. A **$1,025.00** shortfall on one policy.

## Defect 4 — a narrowed field, and a bill for a policy that does not exist

`current.cob` narrows the premium from `9(5)V99` to `9(4)V99`. Running two
otherwise identical programs against one $12,000.00 policy:

```
### RENEWAL-04-CORRECT   BASE-PREM PIC 9(5)V99, 20-byte record
100008  12000.00
RECORDS 0001 TOTAL    12000.00

### RENEWAL-05-NARROW    BASE-PREM PIC 9(4)V99, 19-byte record
100008   1200.00
000008   1200.00
RECORDS 0002 TOTAL     2400.00
```

Two independent failures, neither diagnosed:

**The premium is read through a 6-column window instead of 7.** The implied
decimal lands one place left and $12,000.00 becomes $1,200.00 — an order of
magnitude, on exactly the high-value policies an insurer can least afford to
misprice.

**The record gets shorter, so the deck gains a policy.** Narrowing the field
shortens the record from 20 bytes to 19. The card is still 20 bytes, so the
leftover byte becomes the start of a second record. The batch invents policy
`000008`, which does not exist, and bills it $1,200.00. One input card, two
output bills, and a batch total that is wrong in both directions at once.

## What happens if it shifts one column left

The final lab asks the question. Here is the answer as captured output rather
than prose.

The `FD` declares a 20-byte record and the `SELECT` carries no `ORGANIZATION`
clause, so reads are record sequential: fixed 20-byte slices with no concept
of a line. Feed that program a file where someone has added newlines — the
natural thing for a modern person to do — and the file is 126 bytes instead of
120.

```
### run A: authentic card image, 120 bytes, no delimiters
100001000450.00
100002000545.00
100003000100.00
100004000150.00
100005000050.00
100006000200.00

### run B: the same six records with newlines, 126 bytes
100001000450.00

10000017500.00
0
1000002300.00
00
100002900.00
000
10014100.00
8000
1016700.00
90000
016700.00
```

Record 1 lands correctly. Record 2 starts on the newline byte, and every
record after it walks one column further left. Six policies become eleven
output lines. The program does not crash, does not warn, and does not exit
non-zero — it bills $17,500.00, $2,300.00, $900.00, $4,100.00 and $6,700.00
against policy numbers that were never on a card.

So: nothing announces the shift. Every field remains *readable*, and reading
is all the program does. The output is well-formed, plausible, and entirely
fictional. The only defense is knowing the record layout independently of the
program — which is why the copybook and the data file are worthless apart from
each other, and why "why fixed width matters" is an operational concern rather
than a history lesson.

## Reproducing

```sh
cd lab
make verify
```

`verify` fails if any headline figure stops reproducing, so this document
cannot drift away from the evidence without the build going red.
