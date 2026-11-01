#!/usr/bin/env python3
"""Rebuilds Localizable.xcstrings from the keys the compiler extracted
(build/dd ... *.stringsdata) and scripts/translations-tr.json.
Run after a Debug build: python3 scripts/sync-strings.py"""
import glob, json, sys

keys = {}
for path in glob.glob('build/dd/Build/Intermediates.noindex/Helm.build/Debug/Helm.build/Objects-normal/*/*.stringsdata'):
    for entries in json.load(open(path)).get('tables', {}).values():
        for entry in entries:
            keys[entry['key']] = entry.get('comment')

tr = json.load(open('scripts/translations-tr.json'))
plural_en = {'%lld files': ('%lld file', '%lld files'), '%lld paths copied': ('%lld path copied', '%lld paths copied'), '%lld items': ('%lld item', '%lld items'), '%lld items moved': ('%lld item moved', '%lld items moved'), '%lld images copied': ('%lld image copied', '%lld images copied')}
missing = [k for k in keys if k not in tr]
strings = {}
for key in sorted(keys):
    entry = {}
    if keys[key]:
        entry['comment'] = keys[key]
    loc = {}
    if key in plural_en:
        one, other = plural_en[key]
        loc['en'] = {'variations': {'plural': {
            'one': {'stringUnit': {'state': 'translated', 'value': one}},
            'other': {'stringUnit': {'state': 'translated', 'value': other}}}}}
    if key in tr:
        loc['tr'] = {'stringUnit': {'state': 'translated', 'value': tr[key]}}
    if loc:
        entry['localizations'] = loc
    strings[key] = entry
json.dump({'sourceLanguage': 'en', 'strings': strings, 'version': '1.0'},
          open('Helm/Resources/Localizable.xcstrings', 'w'), ensure_ascii=False, indent=2, sort_keys=True)
print(f'{len(keys)} keys, {len(missing)} without Turkish: {missing}')
sys.exit(1 if missing else 0)
