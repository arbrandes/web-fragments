.PHONY: clean coverage docs help quality requirements test test-all upgrade

.DEFAULT_GOAL := help

define BROWSER_PYSCRIPT
import os, webbrowser, sys
try:
	from urllib import pathname2url
except:
	from urllib.request import pathname2url

webbrowser.open("file://" + pathname2url(os.path.abspath(sys.argv[1])))
endef
export BROWSER_PYSCRIPT
BROWSER := python -c "$$BROWSER_PYSCRIPT"

help: ## display this help message
	@echo "Please use \`make <target>' where <target> is one of"
	@perl -nle'print $& if m{^[a-zA-Z_-]+:.*?## .*$$}' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m  %-25s\033[0m %s\n", $$1, $$2}'

clean: ## remove generated byte code, coverage reports, and build artifacts
	find . -name '*.pyc' -exec rm -f {} +
	find . -name '*.pyo' -exec rm -f {} +
	find . -name '*~' -exec rm -f {} +
	coverage erase
	rm -fr build/
	rm -fr dist/
	rm -fr *.egg-info

COMMON_CONSTRAINTS_TXT=requirements/common_constraints.txt
.PHONY: $(COMMON_CONSTRAINTS_TXT)
$(COMMON_CONSTRAINTS_TXT):
	wget -O "$(@)" https://raw.githubusercontent.com/edx/edx-lint/master/edx_lint/files/common_constraints.txt || touch "$(@)"

upgrade: export CUSTOM_COMPILE_COMMAND=make upgrade
upgrade: $(COMMON_CONSTRAINTS_TXT)
	## update the requirements/*.txt files with the latest packages satisfying requirements/*.in
	pip install -qr requirements/pip-tools.txt
	pip-compile --allow-unsafe --upgrade --rebuild -o requirements/pip.txt requirements/pip.in
	pip-compile --upgrade -o requirements/pip-tools.txt requirements/pip-tools.in
	pip install -qr requirements/pip.txt
	pip install -qr requirements/pip-tools.txt
	pip-compile --upgrade -o requirements/base.txt requirements/base.in
	pip-compile --upgrade -o requirements/dev.txt requirements/dev.in requirements/quality.in
	pip-compile --upgrade --allow-unsafe -o requirements/doc.txt requirements/base.in requirements/doc.in
	pip-compile --upgrade -o requirements/quality.txt requirements/quality.in
	pip-compile --upgrade -o requirements/test.txt requirements/base.in requirements/test.in
	pip-compile --upgrade -o requirements/ci.txt requirements/ci.in
	# Let tox control the Django version for tests
	sed '/Django==/d' requirements/test.txt > requirements/test.tmp
	mv requirements/test.tmp requirements/test.txt

requirements: ## install development environment requirements
	pip install -qr requirements/pip.txt
	pip install -qr requirements/dev.txt --exists-action w
	pip-sync requirements/base.txt requirements/dev.txt requirements/private.* requirements/test.txt

docs: ## generate Sphinx HTML documentation, including API docs
	tox -e docs
	$(BROWSER) docs/_build/html/index.html

quality: ## check coding style with pycodestyle and pylint
	tox -e quality

test: clean ## run tests in the current virtualenv
	py.test

coverage: clean ## generate and view HTML coverage report
	py.test --cov-report html
	$(BROWSER) htmlcov/index.html

diff_cover: test
	diff-cover coverage.xml

test-all: ## run tests on every supported Python/Django combination
	tox -e quality
	tox
