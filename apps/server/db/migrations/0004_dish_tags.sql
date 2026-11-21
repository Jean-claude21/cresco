-- "Mes plats" filters (mockup G): tags set by the user or their AI, never guessed.
alter table plat
  add column tags text[] not null default '{}'
  check (tags <@ array['proteines', 'rapide', 'vegetarien', 'daniel']::text[]);
