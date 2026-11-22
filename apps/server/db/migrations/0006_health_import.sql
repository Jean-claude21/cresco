-- Health import (Health Connect, Apple Santé): daily steps, and no duplicate when the same
-- night or measure is imported twice from the same source.
alter table mesure drop constraint if exists mesure_type_check;
alter table mesure add constraint mesure_type_check
  check (type in ('poids', 'tour_taille', 'masse_grasse', 'vfc', 'fc_repos', 'pas'));
create unique index if not exists mesure_import_unique on mesure (user_id, type, le, source) where source <> 'saisie';
create unique index if not exists nuit_import_unique on nuit (user_id, lever, source) where source <> 'saisie';
