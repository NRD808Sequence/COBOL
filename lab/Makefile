# 1964 insurance renewal batch lab.
#
#   make image      build the pinned GnuCOBOL image
#   make forensics  compile + run the ladder, write 03_forensics/
#   make forensics RUNNER=local     use a host cobc instead of the container
#   make verify     assert the headline numbers are what the write-ups claim
#   make clean      remove generated evidence

IMAGE  ?= cobol-lab:3.1.2
RUNNER ?= docker

# Names the provenance file. Override on the Proxmox guest so the two captures
# sit side by side: make forensics CAPTURE_HOST=proxmox-debian
CAPTURE_HOST ?= macos-docker

.PHONY: all image forensics verify clean

all: forensics

image:
	docker build -t $(IMAGE) 00_environment

ifeq ($(RUNNER),docker)
forensics: image
	docker run --rm -v "$(CURDIR):/lab" -w /lab -e CAPTURE_HOST=$(CAPTURE_HOST) \
		$(IMAGE) sh /lab/00_environment/capture.sh
else
forensics:
	LAB="$(CURDIR)" CAPTURE_HOST=$(CAPTURE_HOST) sh 00_environment/capture.sh
endif

# Guards the three figures the vault docs cite. If a change to the deck or the
# arithmetic moves them, this fails loudly instead of letting the prose drift
# out of sync with the evidence.
verify: forensics
	@grep -qF 'harness-computed batch total: 1495.00' 03_forensics/output-04-multiply-bug.txt \
		|| { echo "FAIL: buggy batch total is not 1495.00"; exit 1; }
	@grep -qF 'harness-computed batch total: 4175.00' 03_forensics/output-04-multiply-bug.txt \
		|| { echo "FAIL: corrected batch total is not 4175.00"; exit 1; }
	@grep -qF '1125.00' 03_forensics/output-05-worked-example.txt \
		|| { echo "FAIL: worked example is not 1125.00"; exit 1; }
	@grep -qF 'status = 41' 03_forensics/output-01-asis.txt \
		|| { echo "FAIL: 01-ASIS no longer fails with file-already-open"; exit 1; }
	@grep -qF 'unexpected *' 03_forensics/output-02-current-asis.txt \
		|| { echo "FAIL: 02-CURRENT-ASIS no longer fails to compile"; exit 1; }
	@grep -qF '000008' 03_forensics/output-06-truncation.txt \
		|| { echo "FAIL: narrowed record no longer invents a phantom policy"; exit 1; }
	@echo "verify: 1495.00 / 4175.00 (delta 2680.00), 1125.00, status 41,"
	@echo "verify: ADD syntax error, and the phantom policy all reproduce."

clean:
	rm -rf 03_forensics/output-*.txt 03_forensics/env-*.txt
