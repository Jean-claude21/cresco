-- "Ma salle": the user's gym and the equipment really available there.
-- The app and the AI (MCP) only propose exercises that this equipment allows.
create table gym (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references utilisateur(id) on delete cascade,
  name text not null check (length(name) between 1 and 120),
  chain text check (chain is null or length(chain) <= 60),
  is_main boolean not null default true,
  updated_at timestamptz not null default now()
);
-- One main gym per user.
create unique index gym_main_per_user on gym (user_id) where is_main;

-- Equipment keys: 'exercise:<exercise id>' for a machine, 'material:<materiel>' for free weights and cardio.
create table gym_equipment (
  gym_id uuid not null references gym(id) on delete cascade,
  user_id uuid not null references utilisateur(id) on delete cascade,
  equipment text not null check (equipment ~ '^(exercise|material):[a-z0-9_-]+$'),
  primary key (gym_id, equipment)
);

alter table gym enable row level security;
create policy proprietaire on gym using (user_id = cresco_uid()) with check (user_id = cresco_uid());
grant select, insert, update, delete on gym to cresco_app;

alter table gym_equipment enable row level security;
create policy proprietaire on gym_equipment using (user_id = cresco_uid()) with check (user_id = cresco_uid());
grant select, insert, update, delete on gym_equipment to cresco_app;
