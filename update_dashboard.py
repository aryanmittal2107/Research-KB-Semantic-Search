from pathlib import Path

html_path = Path("templates/index.html")
js_path = Path("static/js/app.js")

html = html_path.read_text(encoding="utf-8")

ids = [
    "total-papers",
    "research-chunks",
    "citation-links",
    "audit-events",
]

placeholder = "<h3>—</h3>"

if html.count(placeholder) != 4:
    raise SystemExit("Expected exactly four stat placeholders. No changes made.")

for element_id in ids:
    html = html.replace(
        placeholder,
        f'<h3 id="{element_id}">—</h3>',
        1,
    )

html_path.write_text(html, encoding="utf-8")
print("Added IDs to all four dashboard cards.")