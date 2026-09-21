"""Join maintainable source modules into GDN's single-file Starlark entry."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PARTS = ['settings', 'normalize', 'source', 'results', 'icons', 'layout']
text = '\n\n'.join((ROOT / 'src' / (name + '.star')).read_text(encoding='utf-8') for name in PARTS)
(ROOT / 'app.star').write_text(text, encoding='utf-8')
print('Built', ROOT / 'app.star')
