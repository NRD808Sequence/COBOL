# AGENTS.md

## What this repo is

A five-module course that uses COBOL, PROLOG, and LISP to teach how 1960s
programmers reasoned, built around one scenario: 1964 insurance policy
renewal batch processing. The subject is not syntax. It is reconstructing
intent from undocumented code, which is the daily work of legacy
modernization.

## Layout

- `module1_PROLOG/` .. `module5_alienmoon/` — the instructor's material.
  **Read-only.** Two of its five code files contain the defects the lab
  documents; editing them destroys the evidence.
- `lab/` — all of our work.

## The renewal rule

```
NEW PREMIUM = BASE PREMIUM + (25 if AGE > 50) + (50 per claim)
```

## Canonical record layout, 20 bytes

| Columns | Field | PIC |
|---|---|---|
| 1-6 | POL-NUM | `9(6)` |
| 7-8 | STATE | `XX` |
| 9-10 | AGE | `9(2)` |
| 11 | VEHICLE | `X` (S sedan, P sports, T truck) |
| 12-13 | CLAIMS | `9(2)` |
| 14-20 | BASE-PREM | `9(5)V99` |

Three incompatible layouts exist in the instructor's material. This one is
adopted because it is the only superset that supports every downstream
consumer; the reasoning is in `lab/01_record_layout/LAYOUT.md`.

The `V` is an implied decimal occupying no column. $450.00 is punched
`0045000`.

## Commands

```sh
cd lab
make forensics                          # compile + run the ladder, capture evidence
make verify                             # assert the headline figures still reproduce
make forensics RUNNER=local             # use a host cobc instead of the container
make forensics CAPTURE_HOST=proxmox-debian
```

Docker is the canonical runner so macOS and Proxmox produce identical
`output-*.txt`. Host-varying detail goes to `env-*.txt` instead.

## Conventions

- Fixed-format COBOL only. Column position is syntax. See
  `.cursor/rules/cobol-fixed-format.mdc`.
- Input decks are card images: fixed-length records, no line delimiters. The
  `.DAT` files carry newlines for editing; `capture.sh` derives the `.CARD`
  images so the two cannot drift.
- One variable per rung. Each program in `lab/02_cobol/` differs from its
  predecessor by exactly one change, so every artifact isolates one defect.
- Every figure in a write-up cites a captured artifact and is guarded by
  `make verify`.

## Branching — never merge `lab/*` into `main`

`main` is the instructor's tree. `lab/foundation` is ours. Merging them is a
hard no: it mixes submitted coursework with the forensics and destroys the
evidence.

Work stays on `lab/foundation`. A GitHub Action fails any PR or push that
puts `lab/` onto `main`. Enable the local hook once per clone:

```sh
git config core.hooksPath .githooks
```

## Coordination

A parallel session owns the Obsidian vault and folds our evidence into its
notes. It is read-only from here. Hand results back via
`lab/03_forensics/VAULT-EVIDENCE.md`. Do not write outside this repo.
