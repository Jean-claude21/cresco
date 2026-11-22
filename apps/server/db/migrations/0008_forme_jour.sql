-- Daily form components (C-FORME), kept to calibrate the user's own weights (C-CALIB).
create table forme_jour (
  user_id uuid not null references utilisateur(id) on delete cascade,
  jour date not null,
  composantes jsonb not null,
  valeur numeric not null,
  primary key (user_id, jour)
);
alter table forme_jour enable row level security;
create policy proprietaire on forme_jour using (user_id = cresco_uid()) with check (user_id = cresco_uid());
grant select, insert, update, delete on forme_jour to cresco_app;
