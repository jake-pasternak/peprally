-- peprally · seed data
-- The peptide topic catalog. Hex tints match the client's FeedTopics palette.
-- Idempotent so it can be re-run: conflicts on slug do nothing.

insert into topics (slug, name, hex, sort_order) values
    ('bpc-157',     'BPC-157',     'E9DAD5', 10),
    ('semaglutide', 'Semaglutide', 'CFD9E2', 20),
    ('tb-500',      'TB-500',      'EBECE7', 30),
    ('nad',         'NAD+',        'E8E8E6', 40),
    ('tirzepatide', 'Tirzepatide', 'DDE4DA', 50),
    ('ipamorelin',  'Ipamorelin',  'E7E0EA', 60),
    ('cjc-1295',    'CJC-1295',    'E9E3D6', 70),
    ('ghk-cu',      'GHK-Cu',      'D8E1E4', 80),
    ('mots-c',      'MOTS-c',      'E4DAD8', 90),
    ('epithalon',   'Epithalon',   'DEE3E8', 100)
on conflict (slug) do nothing;
