#!/bin/sh
# Compile and run the bisect ladder, capturing every artifact under 03_forensics/.
#
# Runs identically inside the pinned container and on a host with cobc on PATH,
# so the macOS and Proxmox captures can be compared with a plain diff. Anything
# that legitimately varies by host (compiler build, kernel, arch) is written to
# env-*.txt instead of output-*.txt, so the output files stay byte-identical.

set -u

LAB="${LAB:-/lab}"
SRC="$LAB/02_cobol"
DATA="$LAB/01_record_layout"
OUT="$LAB/03_forensics"
FLAGS="-x -std=cobol85 -Wall"

mkdir -p "$OUT"
WORK=$(mktemp -d) || exit 1
trap 'rm -rf "$WORK"' EXIT

# A 1964 card deck carries no line delimiters: six 20-column records is 120
# contiguous bytes. The .DAT files keep newlines so they stay hand-editable;
# the .CARD images are derived here so the two forms can never drift apart.
for d in POLICY POLICY-WORKED-EXAMPLE POLICY-TRUNCATION; do
    tr -d '\n' < "$DATA/$d.DAT" > "$WORK/$d.CARD"
done

# compile <program>  -> binary at $WORK/<program>, diagnostics on stdout
compile() {
    cobc $FLAGS "$SRC/$1.cob" -o "$WORK/$1" 2>&1
    echo "compile exit=$?"
}

# run <program> <deck>  -- deck is staged as POLICY.DAT in a clean directory,
# because every program in the ladder hardcodes that filename. Derived .CARD
# images live in $WORK; the hand-edited .DAT sources live in $DATA.
run() {
    rm -rf "$WORK/run"
    mkdir -p "$WORK/run"
    _deck="$WORK/$2"
    [ -f "$_deck" ] || _deck="$DATA/$2"
    cp "$_deck" "$WORK/run/POLICY.DAT"
    ( cd "$WORK/run" && "$WORK/$1" 2>&1; echo "run exit=$?" ) | tee "$WORK/last-run.txt"
}

# Sum the premium column of the run just captured. The faithful 1964 programs
# have no totals paragraph, so the harness derives the batch figure rather than
# editing the source under examination to make it report one.
harness_total() {
    awk '/^[0-9][0-9][0-9][0-9][0-9][0-9]/ { s += substr($0, 7) + 0 }
         END { printf "harness-computed batch total: %.2f\n", s }' "$WORK/last-run.txt"
}

# The billing report is a record-sequential print image with no delimiters,
# exactly like a 1964 printer file. Fold it to 60 columns to read it.
show_report() {
    if [ -f "$WORK/run/BILLING.RPT" ]; then
        echo "--- BILLING.RPT (folded to the 60-column print line) ---"
        fold -w 60 "$WORK/run/BILLING.RPT"
    fi
}

header() {
    echo "$1"
    echo "$2"
    echo
}

# ---------------------------------------------------------------- provenance
HOST="${CAPTURE_HOST:-$(hostname)}"
ENVFILE="$OUT/env-$HOST.txt"
{
    echo "Toolchain provenance. Values here are EXPECTED to differ between the"
    echo "macOS and Proxmox captures; the output-*.txt files are not."
    echo
    echo "captured-by : capture.sh"
    echo "capture host: $HOST"
    echo "container id: $(hostname)"
    echo "kernel      : $(uname -srm)"
    echo "base image  : debian:bookworm-slim"
    echo "base digest : sha256:abd67ffcfa541b485a3dff59865ab629aa048a6c613e639d36e7456b0b229241"
    echo "cobc flags  : $FLAGS"
    echo
    cobc --version
} > "$ENVFILE"

# ------------------------------------------------- 01: the runtime crash
{
    header "DEFECT 2 - OPEN INPUT inside the loop target" \
           "RENEWAL-01-ASIS.cob is module4_LISP/lab2/cobol/cobol1.cob, verbatim."
    echo "### compile"
    compile RENEWAL-01-ASIS
    echo
    echo "### run against the authentic 120-byte card image"
    run RENEWAL-01-ASIS POLICY.CARD
    echo
    echo "GO TO MAIN-LOOP re-enters the paragraph holding OPEN INPUT, so the"
    echo "second iteration re-opens an already-open file. One record is billed"
    echo "out of six. The program cannot process a deck at all."
} > "$OUT/output-01-asis.txt" 2>&1

# ------------------------------------------------- 02: the compile error
{
    header "DEFECT 1 - arithmetic expression inside ADD" \
           "RENEWAL-02-CURRENT-ASIS.cob is module5_alienmoon/cobol/current.cob, verbatim."
    echo "### compile"
    compile RENEWAL-02-CURRENT-ASIS
    echo
    echo "ADD ... TO takes operands, not expressions. This program never runs,"
    echo "and that is the finding: module5 shipped code that was never compiled."
    echo "The portable fix is COMPUTE NEW-PREM = NEW-PREM + (CLAIMS * 50)."
} > "$OUT/output-02-current-asis.txt" 2>&1

# ------------------------------------------------- 03: column shift
{
    header "THE ONE-COLUMN QUESTION - record sequential vs. a newline-delimited file" \
           "Same binary, same logic, two physical file formats."
    echo "### compile"
    compile RENEWAL-03-LOOPFIX
    echo
    echo "### run A: authentic card image, 120 bytes, no delimiters"
    run RENEWAL-03-LOOPFIX POLICY.CARD
    echo
    echo "### run B: the same six records with newlines, 126 bytes"
    run RENEWAL-03-LOOPFIX POLICY.DAT
    echo
    echo "The FD declares a 20-byte record and the SELECT has no ORGANIZATION"
    echo "clause, so reads are record sequential: fixed 20-byte slices with no"
    echo "notion of a line. Record 1 lands correctly. Record 2 begins on the"
    echo "newline byte, and every record after it is shifted one column left."
    echo "The newline is the anachronism, not the COBOL."
} > "$OUT/output-03-loopfix-columnshift.txt" 2>&1

# ------------------------------------------------- 03 vs 04: the money bug
{
    header "DEFECT 3 - MULTIPLY ... GIVING overwrites the accumulator" \
           "Both runs use the authentic card image, so only the arithmetic differs."
    echo "### RENEWAL-03-LOOPFIX (MULTIPLY CLAIMS BY 50 GIVING NEW-PREM)"
    run RENEWAL-03-LOOPFIX POLICY.CARD
    harness_total
    echo
    echo "### RENEWAL-04-CORRECT (COMPUTE NEW-PREM = NEW-PREM + (CLAIMS * 50))"
    compile RENEWAL-04-CORRECT
    run RENEWAL-04-CORRECT POLICY.CARD
    harness_total
    show_report
    echo
    echo "GIVING assigns. It discards the base premium and the age surcharge"
    echo "computed on the two lines above it. Note policies 100001 and 100002:"
    echo "identical under both programs, because both are claim-free. The"
    echo "defect is invisible on every policy that had no claims that year."
} > "$OUT/output-04-multiply-bug.txt" 2>&1

# ------------------------------------------------- the worked example
{
    header "WORKED EXAMPLE - base \$1,000.00, age 60, 2 claims" \
           "The single policy cited in the vault's Bug Diff Analysis."
    echo "### buggy (RENEWAL-03-LOOPFIX)"
    run RENEWAL-03-LOOPFIX POLICY-WORKED-EXAMPLE.CARD
    echo
    echo "### correct (RENEWAL-04-CORRECT)"
    run RENEWAL-04-CORRECT POLICY-WORKED-EXAMPLE.CARD
    echo
    echo "Intended 1000.00 + 25.00 + 100.00 = 1125.00. Buggy 2 * 50 = 100.00."
} > "$OUT/output-05-worked-example.txt" 2>&1

# ------------------------------------------------- 05: silent truncation
{
    header "DEFECT 4 - narrowed PICTURE clause on a high-value policy" \
           "One policy, base premium \$12,000.00, age 45, no claims."
    echo "### RENEWAL-04-CORRECT   BASE-PREM PIC 9(5)V99, 20-byte record"
    run RENEWAL-04-CORRECT POLICY-TRUNCATION.CARD
    echo
    echo "### RENEWAL-05-NARROW    BASE-PREM PIC 9(4)V99, 19-byte record"
    compile RENEWAL-05-NARROW
    run RENEWAL-05-NARROW POLICY-TRUNCATION.CARD
    echo
    echo "Identical programs but for the PICTURE width module5 narrowed."
    echo "Two things go wrong at once, and neither raises a diagnostic."
    echo
    echo "First, the premium is read from a 6-column window instead of 7, so"
    echo "the implied decimal lands one place left: 12000.00 becomes 1200.00,"
    echo "an order of magnitude under-billed."
    echo
    echo "Second, the narrower field shortens the whole record from 20 bytes"
    echo "to 19. The deck is still 20 bytes long, so the leftover byte becomes"
    echo "the start of a second record. The batch invents policy 000008, which"
    echo "does not exist, and bills it. One input card, two output bills."
} > "$OUT/output-06-truncation.txt" 2>&1

echo "capture complete:"
ls -1 "$OUT"
