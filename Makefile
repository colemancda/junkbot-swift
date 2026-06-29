.PHONY: all clean serve

all:
	@echo "▶ Installing dependencies…"
	npm install
	@echo "✓ Done."

clean:
	rm -rf node_modules

serve:
	@echo "▶ Starting dev server…"
	npm start
