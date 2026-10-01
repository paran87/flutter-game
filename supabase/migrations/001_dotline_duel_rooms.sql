-- Dotline Duel: Private Room multiplayer schema
-- Apply this to your Supabase project via the SQL editor or CLI.

-- ---------------------------------------------------------------- rooms
create table if not exists public.rooms (
  id            uuid primary key default gen_random_uuid(),
  code          text not null unique,
  status        text not null default 'waiting'
                  check (status in ('waiting', 'playing', 'finished')),
  obstacle_seed bigint not null,
  host_id       text not null,
  guest_id      text,
  match_start_at timestamptz,
  created_at    timestamptz not null default now()
);

-- Rooms older than 30 minutes are stale; a cron job (or the app) can clean them.
create index if not exists rooms_code_idx   on public.rooms (code);
create index if not exists rooms_status_idx on public.rooms (status, created_at);

-- RLS: anyone with the anon key can read, insert and update rooms.
-- The app only uses the anon (public) key, so we keep this open.
-- You can tighten this later with auth.uid() once you add authentication.
alter table public.rooms enable row level security;

create policy "rooms: anyone can read"
  on public.rooms for select using (true);

create policy "rooms: anyone can insert"
  on public.rooms for insert with check (true);

create policy "rooms: anyone can update"
  on public.rooms for update using (true);

-- ---------------------------------------------------------------- Realtime
-- Enable Realtime on the rooms table so the Flutter app receives live updates.
alter publication supabase_realtime add table public.rooms;
