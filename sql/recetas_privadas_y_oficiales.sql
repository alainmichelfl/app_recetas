-- ==============================================================================
-- 🍳 SCRIPT DE SEGMENTACIÓN: RECETAS PRIVADAS VS. CATÁLOGO OFICIAL
-- Proyecto: Jitomate y Cebolla (App Recetas)
-- ==============================================================================
--
-- ¿QUÉ HACE ESTE SCRIPT?
-- 1. Agrega las columnas 'user_id', 'es_oficial' y 'es_publica' a la tabla 'recetas'.
-- 2. Marca todas las recetas existentes actuales como OFICIALES y PÚBLICAS.
-- 3. Crea índices de alto rendimiento para filtrar rápidamente por tipo de receta.
-- 4. Actualiza las políticas RLS:
--    - Lectura: Todo usuario puede leer recetas oficiales, comunitarias y las propias.
--    - Inserción: Usuarios autenticados pueden registrar recetas privadas o comunitarias.
--    - Modificación / Borrado: Solo el dueño de la receta o el Administrador (alainmichel.fl@gmail.com).
--
-- INSTRUCCIONES:
-- 1. Abre Supabase: https://supabase.com/dashboard/project/xjfzlthgycczcjbifaty
-- 2. Ve a "SQL Editor" en el menú izquierdo.
-- 3. Crea una "New Query", pega todo este código y presiona "Run".
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. AGREGAR COLUMNAS A LA TABLA public.recetas
-- ------------------------------------------------------------------------------
ALTER TABLE public.recetas 
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS es_oficial BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS es_publica BOOLEAN DEFAULT false;

-- ------------------------------------------------------------------------------
-- 2. MIGRAR RECETAS EXISTENTES COMO OFICIALES Y PÚBLICAS
-- ------------------------------------------------------------------------------
-- Las recetas creadas hasta el momento forman parte del recetario insignia de la app.
UPDATE public.recetas 
SET es_oficial = true, es_publica = true 
WHERE es_oficial IS NULL OR es_oficial = false;

-- ------------------------------------------------------------------------------
-- 3. ÍNDICES DE ALTO RENDIMIENTO
-- ------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_recetas_user_id ON public.recetas(user_id);
CREATE INDEX IF NOT EXISTS idx_recetas_es_oficial ON public.recetas(es_oficial);
CREATE INDEX IF NOT EXISTS idx_recetas_es_publica ON public.recetas(es_publica);

-- ------------------------------------------------------------------------------
-- 4. ACTUALIZAR ROW LEVEL SECURITY (RLS) EN public.recetas
-- ------------------------------------------------------------------------------
ALTER TABLE public.recetas ENABLE ROW LEVEL SECURITY;

-- A) LECTURA UNIFICADA:
-- Un usuario puede leer:
-- 1. Recetas oficiales de la app (es_oficial = true).
-- 2. Recetas compartidas con la comunidad (es_publica = true).
-- 3. Sus propias recetas privadas (user_id = auth.uid()).
DROP POLICY IF EXISTS "recetas_lectura_publica" ON public.recetas;
DROP POLICY IF EXISTS "recetas_lectura_unificada" ON public.recetas;

CREATE POLICY "recetas_lectura_unificada" ON public.recetas
  FOR SELECT USING (
    es_oficial = true 
    OR es_publica = true 
    OR (auth.uid() IS NOT NULL AND auth.uid() = user_id)
    OR user_id IS NULL
  );

-- B) INSERCIÓN:
-- Cualquier usuario autenticado puede agregar sus recetas (privadas o públicas).
DROP POLICY IF EXISTS "recetas_insert_autenticado" ON public.recetas;

CREATE POLICY "recetas_insert_autenticado" ON public.recetas
  FOR INSERT WITH CHECK (
    auth.role() = 'authenticated'
  );

-- C) MODIFICACIÓN:
-- Solo el usuario creador o el administrador pueden editar la receta.
DROP POLICY IF EXISTS "recetas_modificar_propia" ON public.recetas;

CREATE POLICY "recetas_modificar_propia" ON public.recetas
  FOR UPDATE USING (
    (auth.uid() IS NOT NULL AND auth.uid() = user_id)
    OR auth.jwt() ->> 'email' = 'alainmichel.fl@gmail.com'
  )
  WITH CHECK (
    (auth.uid() IS NOT NULL AND auth.uid() = user_id)
    OR auth.jwt() ->> 'email' = 'alainmichel.fl@gmail.com'
  );

-- D) ELIMINACIÓN:
-- Solo el usuario creador o el administrador pueden eliminar la receta.
DROP POLICY IF EXISTS "recetas_borrar_propia" ON public.recetas;

CREATE POLICY "recetas_borrar_propia" ON public.recetas
  FOR DELETE USING (
    (auth.uid() IS NOT NULL AND auth.uid() = user_id)
    OR auth.jwt() ->> 'email' = 'alainmichel.fl@gmail.com'
  );
