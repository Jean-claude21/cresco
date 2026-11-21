-- Cresco — schéma initial. Chaque donnée personnelle porte user_id et est protégée par la sécurité
-- au niveau des lignes : le rôle applicatif cresco_app ne voit que les lignes de l'utilisateur
-- défini par set_config('cresco.user_id', …) dans la transaction (voir src/db.ts, asUser).

create extension if not exists pgcrypto;

do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'cresco_app') then
    create role cresco_app nologin nobypassrls;
  end if;
end $$;

create or replace function cresco_uid() returns uuid language sql stable as
$$ select nullif(current_setting('cresco.user_id', true), '')::uuid $$;

-- Comptes et jetons : lus par l'authentification avant de connaître l'utilisateur, donc hors RLS.
create table utilisateur (
  id uuid primary key default gen_random_uuid(),
  email text not null unique check (email = lower(email)),
  mot_de_passe text not null,
  nom text not null default '',
  sexe text check (sexe in ('homme', 'femme')),
  naissance date,
  taille_cm numeric,
  niveau text not null default 'intermediaire' check (niveau in ('debutant', 'intermediaire', 'avance')),
  objectif text not null default 'maintien' check (objectif in ('perte', 'maintien', 'prise')),
  activite text not null default 'actif' check (activite in ('sedentaire', 'peu_actif', 'actif', 'tres_actif')),
  preferences jsonb not null default '{"moduleFoi": false, "prioriteSpirituelle": false, "joursReposVerrouilles": [], "besoinSommeilMin": 480}',
  consentements jsonb not null default '{}',
  cree_le timestamptz not null default now()
);

create table jeton (
  id uuid primary key default gen_random_uuid(),
  utilisateur_id uuid not null references utilisateur(id) on delete cascade,
  empreinte text not null unique,
  nom text not null,
  scopes text[] not null,
  cree_le timestamptz not null default now(),
  dernier_usage timestamptz,
  revoque_le timestamptz
);

create table journal_acces (
  id bigserial primary key,
  utilisateur_id uuid not null references utilisateur(id) on delete cascade,
  jeton_id uuid,
  porte text not null,
  action text not null,
  le timestamptz not null default now()
);

-- Catalogue d'exercices commun (lecture pour tous).
create table exercice (
  id text primary key,
  nom text not null,
  muscles_primaires text[] not null,
  muscles_secondaires text[] not null default '{}',
  materiel text not null,
  pas_kg numeric not null default 2.5,
  consignes text not null default '',
  animation text
);

create table exercice_lien (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references utilisateur(id) on delete cascade,
  exercice_id text not null references exercice(id),
  url text not null check (url ~ '^https://'),
  titre text not null default ''
);

create table modele_seance (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references utilisateur(id) on delete cascade,
  nom text not null,
  type text not null,
  contenu jsonb not null,
  cree_par text not null default 'utilisateur',
  cree_le timestamptz not null default now()
);

create table seance (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references utilisateur(id) on delete cascade,
  le timestamptz not null default now(),
  modele_id uuid references modele_seance(id) on delete set null,
  type text not null,
  decision jsonb,
  rpe numeric,
  duree_min numeric,
  srpe numeric,
  notes text not null default ''
);

create table serie (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references utilisateur(id) on delete cascade,
  seance_id uuid not null references seance(id) on delete cascade,
  exercice_id text references exercice(id),
  ordre int not null,
  reps int,
  charge_kg numeric,
  rir numeric,
  vitesse_ms numeric,
  fc numeric,
  duree_s numeric,
  e1rm numeric
);

create table aliment (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references utilisateur(id) on delete cascade,
  source text not null check (source in ('off', 'ciqual', 'perso')),
  code_barres text,
  nom text not null,
  kcal100 numeric not null,
  proteines100 numeric not null default 0,
  glucides100 numeric not null default 0,
  lipides100 numeric not null default 0,
  fibres100 numeric not null default 0
);
create unique index aliment_off_code on aliment (code_barres) where source = 'off';

create table plat (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references utilisateur(id) on delete cascade,
  nom text not null,
  ingredients jsonb not null,
  masse_cuite numeric,
  nutriments jsonb not null,
  cree_par text not null default 'utilisateur',
  cree_le timestamptz not null default now()
);

create table repas (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references utilisateur(id) on delete cascade,
  le timestamptz not null default now(),
  type text not null default 'repas',
  portions jsonb not null,
  kcal numeric not null,
  proteines numeric not null,
  glucides numeric not null,
  lipides numeric not null
);

create table nuit (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references utilisateur(id) on delete cascade,
  coucher timestamptz not null,
  lever timestamptz not null,
  dormi_min numeric not null,
  au_lit_min numeric not null,
  profond_pct numeric,
  source text not null default 'saisie'
);

create table mesure (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references utilisateur(id) on delete cascade,
  le timestamptz not null default now(),
  type text not null check (type in ('poids', 'tour_taille', 'masse_grasse', 'vfc', 'fc_repos')),
  valeur numeric not null,
  source text not null default 'saisie'
);

create table ressenti (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references utilisateur(id) on delete cascade,
  le timestamptz not null default now(),
  energie int check (energie between 1 and 5),
  courbatures int check (courbatures between 0 and 3),
  clarte int check (clarte between 1 and 5),
  spirituel int check (spirituel between 1 and 5),
  maladie boolean not null default false,
  notes text not null default ''
);

create table jeune (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references utilisateur(id) on delete cascade,
  type text not null check (type in ('intermittent', 'eau', 'sec', 'partiel')),
  motif text not null default 'spirituel' check (motif in ('spirituel', 'sante', 'autre')),
  intention text not null default '',
  debut timestamptz not null default now(),
  fin_prevue timestamptz,
  fin_reelle timestamptz
);

create table evenement_jeune (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references utilisateur(id) on delete cascade,
  jeune_id uuid not null references jeune(id) on delete cascade,
  le timestamptz not null default now(),
  type text not null check (type in ('eau', 'electrolytes', 'symptome', 'clarte', 'energie', 'spirituel', 'poids')),
  valeur text not null
);

create index on seance (user_id, le);
create index on serie (seance_id);
create index on repas (user_id, le);
create index on nuit (user_id, lever);
create index on mesure (user_id, type, le);
create index on jeune (user_id, debut);

-- Sécurité au niveau des lignes.
do $$
declare t text;
begin
  foreach t in array array['exercice_lien', 'modele_seance', 'seance', 'serie', 'plat', 'repas', 'nuit', 'mesure', 'ressenti', 'jeune', 'evenement_jeune'] loop
    execute format('alter table %I enable row level security', t);
    execute format('alter table %I force row level security', t);
    execute format('create policy proprietaire on %I using (user_id = cresco_uid()) with check (user_id = cresco_uid())', t);
    execute format('grant select, insert, update, delete on %I to cresco_app', t);
  end loop;
end $$;

alter table aliment enable row level security;
alter table aliment force row level security;
create policy lecture on aliment for select using (user_id is null or user_id = cresco_uid());
create policy ecriture_perso on aliment for insert with check (user_id = cresco_uid() or (user_id is null and source = 'off'));
grant select, insert on aliment to cresco_app;

grant select on exercice to cresco_app;
grant select, insert, update, delete on utilisateur, jeton to cresco_app;
grant select, insert on journal_acces to cresco_app;
grant usage on sequence journal_acces_id_seq to cresco_app;
grant execute on function cresco_uid() to cresco_app;
