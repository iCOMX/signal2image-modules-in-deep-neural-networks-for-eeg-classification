# NAME
# 	Reproducible builds for computational research papers Makefile help.
# 
# SYNTAX
# 	make [OPTION] [ARGS=--full] [GPU='--gpus all']
# 
# OPTIONS

.POSIX:

ARGS = 
GPU = 

ms.pdf: ms.tex ms.bib results # (or empty) Generate pdf with results from venv.
	make docker-pdf

results: .venv/bin/activate $(shell find . -maxdepth 1 -name '*.py')
	rm -rf $@/*
	. .venv/bin/activate; python3 main.py $(ARGS) --cache-dir cache --results-dir results

.venv/bin/activate: requirements.txt
	rm -rf .venv/*
	python3 -m venv .venv/
	. .venv/bin/activate; python3 -m pip install -U pip wheel; python3 -m pip install -Ur $<

venv-verify: # Verify venv paper reproducibility.
	make clean && make && mv ms.pdf tmp.pdf
	make clean && make
	@diff ms.pdf tmp.pdf && (echo 'ms.pdf is reproducible with venv' && sha256sum ms.pdf) || echo 'ms.pdf is not reproducible with venv'
	@rm tmp.pdf

docker: # Generate pdf with results from docker.
	docker build -t signal2image-modules-in-deep-neural-networks-for-eeg-classification .
	docker run --rm \
		--user $(shell id -u):$(shell id -g) \
		-w /usr/src/app \
		-e HOME=/usr/src/app/cache \
		-v $(PWD):/usr/src/app \
		$(GPU) signal2image-modules-in-deep-neural-networks-for-eeg-classification \
		python3 main.py $(ARGS) --cache-dir cache --results-dir results
	make docker-pdf

docker-verify: # Verify docker paper reproducibility.
	make clean && make docker && mv ms.pdf tmp.pdf
	make clean && make docker
	@diff ms.pdf tmp.pdf && (echo 'ms.pdf is reproducible with docker' && sha256sum ms.pdf) || echo 'ms.pdf is not reproducible with docker'
	@rm tmp.pdf

docker-pdf:
	docker run --rm \
		--user $(shell id -u):$(shell id -g) \
		-v $(PWD)/:/home/latex \
		aergus/latex \
		latexmk -usepretex="\pdfinfoomitdate=1\pdfsuppressptexinfo=-1\pdftrailerid{}" -gg -pdf -cd -quiet /home/latex/ms.tex

clean: # Remove cache, results, venv directories and tex auxiliary files.
	rm -rf __pycache__/ cache/* results/* .venv/* ms.bbl
	docker run --rm \
		--user $(shell id -u):$(shell id -g) \
		-v $(PWD)/:/home/latex \
		aergus/latex \
		latexmk -C -cd /home/latex/ms.tex

help: # Show help.
	@grep '^# ' Makefile | cut -b 3-
	@grep -E '^[a-zA-Z._-]+:.*?# .*$$' Makefile | awk 'BEGIN {FS = ":.*?# "}; {printf "	%-13s - %s\n", $$1, $$2}'
