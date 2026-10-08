-- Ejecutar en Supabase > SQL Editor
create table if not exists public.preferencias_usuario (
  id bigint generated always as identity primary key,
  user_id uuid not null unique default auth.uid() references auth.users(id) on delete cascade,
  objetivo text not null default 'Mantenimiento',
  estilos_dieta text not null default 'Libre',
  alergias text not null default '',
  super_favorito text not null default 'Walmart',
  porciones int4 not null default 2,
  presupuesto_semanal float8 not null default 1500,
  notificaciones boolean not null default true,
  actualizado_en timestamptz not null default now()
);

alter table public.preferencias_usuario enable row level security;

create policy "prefs_select_propias" on public.preferencias_usuario
  for select using (auth.uid() = user_id);
create policy "prefs_insert_propias" on public.preferencias_usuario
  for insert with check (auth.uid() = user_id);
create policy "prefs_update_propias" on public.preferencias_usuario
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
