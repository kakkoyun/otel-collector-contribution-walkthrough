.PHONY: all build pdf html watch serve clean validate install help

all: build

MARP_CONFIG := marp/marp.config.js
SRC := presentation.md
COMMON_FLAGS := --allow-local-files --theme-set marp/css/

build: pdf

pdf:
	npx marp --config $(MARP_CONFIG) $(SRC) $(COMMON_FLAGS) -o presentation.pdf

html:
	npx marp --config $(MARP_CONFIG) $(SRC) $(COMMON_FLAGS) -o presentation.html

watch:
	npx marp --config $(MARP_CONFIG) $(SRC) $(COMMON_FLAGS) --watch --preview

serve: html
	@echo "==> Serving on http://localhost:8000"
	@echo "==> Open in VS Code: Simple Browser → http://localhost:8000/presentation.html"
	python3 -m http.server 8000

clean:
	rm -f presentation.pdf presentation.html

install:
	npm install

validate: html
	@echo "==> Build OK"
	@echo "==> Counting slides..."
	@SLIDES=$$(grep -c '^\-\-\-$$' $(SRC)); echo "    Slide separators found: $$SLIDES"
	@echo "==> Checking for unresolved placeholders..."
	@if grep -q 'PERMALINK_PLACEHOLDER' $(SRC); then \
		echo "    WARNING: Unresolved PERMALINK_PLACEHOLDER found!"; \
		grep -n 'PERMALINK_PLACEHOLDER' $(SRC); \
	else \
		echo "    All permalinks resolved."; \
	fi
	@echo "==> Validation complete."

help:
	@echo "Presentation:"
	@echo "  make build     - Generate PDF (default)"
	@echo "  make html      - Generate HTML"
	@echo "  make watch     - Live preview"
	@echo "  make validate  - Build HTML and check for issues"
	@echo ""
	@echo "Setup:"
	@echo "  make install   - Install npm dependencies"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean     - Remove generated files"
