-- OAuth 2.1 for third-party apps and AI assistants (src/oauth.ts): registered public clients,
-- one-use authorization codes (PKCE), rotated refresh tokens. Server-side tables, like jeton.
create table oauth_client (
  id text primary key,
  nom text not null,
  redirect_uris text[] not null,
  cree_le timestamptz not null default now()
);
create table oauth_code (
  empreinte text primary key,
  client_id text not null references oauth_client(id) on delete cascade,
  utilisateur_id uuid not null references utilisateur(id) on delete cascade,
  redirect_uri text not null,
  scopes text[] not null,
  challenge text not null,
  expire_le timestamptz not null,
  utilise boolean not null default false
);
create table oauth_refresh (
  empreinte text primary key,
  client_id text not null references oauth_client(id) on delete cascade,
  utilisateur_id uuid not null references utilisateur(id) on delete cascade,
  scopes text[] not null,
  jeton_id uuid not null references jeton(id) on delete cascade,
  expire_le timestamptz not null,
  revoque_le timestamptz
);
grant select, insert, update, delete on oauth_client, oauth_code, oauth_refresh to cresco_app;
