-- Script SQL para nombres de usuario únicos en Jitomate y Cebolla
-- Ejecutar en Supabase > SQL Editor

create table if not exists public.nombres_usuario (
  nombre_usuario text primary key,
  user_id uuid not null unique references auth.users(id) on delete cascade,
  actualizado_en timestamptz not null default now()
);

-- Habilitar Row Level Security
alter table public.nombres_usuario enable row level security;

-- Cualquier usuario puede consultar si un nombre está disponible
create policy "nombres_select_publico" on public.nombres_usuario
  for select using (true);

-- Solo el usuario autenticado puede registrar su propio nombre de usuario
create policy "nombres_insert_propias" on public.nombres_usuario
  for insert with check (auth.uid() = user_id);

-- Solo el usuario autenticado puede modificar su propio nombre de usuario
create policy "nombres_update_propias" on public.nombres_usuario
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Solo el usuario autenticado puede eliminar su propio registro
create policy "nombres_delete_propias" on public.nombres_usuario
  for delete using (auth.uid() = user_id);

-- Índice insensible a mayúsculas para búsquedas ágiles
create index if not exists idx_nombres_usuario_lower on public.nombres_usuario (lower(nombre_usuario));
