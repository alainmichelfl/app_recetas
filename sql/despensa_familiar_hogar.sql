-- ==============================================================================
-- 🏠👨‍👩‍👧‍👦 SCRIPT DE DESPENSA FAMILIAR COMPARTIDA (HOGAR MULTI-USUARIO)
-- Proyecto: Jitomate y Cebolla
-- ==============================================================================
--
-- ¿QUÉ HACE ESTE SCRIPT?
-- 1. Crea las tablas 'hogares' y 'miembros_hogar' para vincular cuentas familiares
--    mediante un código único corto (ej. CASA-4829).
-- 2. Asegura que 'despensa_usuario', 'lista_compras' y 'planeador_semanal' tengan
--    las columnas 'user_id' (con valor por defecto auth.uid()) y 'agregado_por'.
-- 3. Crea la función inteligente 'es_miembro_mismo_hogar(target_user_id)' que permite
--    que todos los integrantes del mismo hogar vean, agreguen, editen y tachen
--    en tiempo real la misma Despensa, Lista de Compras y Planeador Semanal.
--
-- INSTRUCCIONES:
-- 1. Abre Supabase: https://supabase.com/dashboard/project/xjfzlthgycczcjbifaty
-- 2. Ve a "SQL Editor" en el menú izquierdo.
-- 3. Crea una "New Query", pega todo este código y presiona "Run".
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. CREAR TABLAS DE HOGAR FAMILIAR
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.hogares (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo TEXT UNIQUE NOT NULL,
  nombre TEXT NOT NULL DEFAULT 'Mi Hogar Familiar',
  creador_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  creado_en TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.miembros_hogar (
  id BIGSERIAL PRIMARY KEY,
  hogar_id UUID NOT NULL REFERENCES public.hogares(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  rol TEXT DEFAULT 'miembro',
  unido_en TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id)
);

CREATE INDEX IF NOT EXISTS idx_hogares_codigo ON public.hogares(codigo);
CREATE INDEX IF NOT EXISTS idx_miembros_hogar_hogar_id ON public.miembros_hogar(hogar_id);
CREATE INDEX IF NOT EXISTS idx_miembros_hogar_user_id ON public.miembros_hogar(user_id);

-- ------------------------------------------------------------------------------
-- 2. ASEGURAR COLUMNAS DE TRAZABILIDAD EN DESPENSA, CARRITO Y PLANEADOR
-- ------------------------------------------------------------------------------
ALTER TABLE public.despensa_usuario
  ADD COLUMN IF NOT EXISTS user_id UUID DEFAULT auth.uid(),
  ADD COLUMN IF NOT EXISTS agregado_por TEXT;

ALTER TABLE public.lista_compras
  ADD COLUMN IF NOT EXISTS user_id UUID DEFAULT auth.uid(),
  ADD COLUMN IF NOT EXISTS agregado_por TEXT;

ALTER TABLE public.planeador_semanal
  ADD COLUMN IF NOT EXISTS user_id UUID DEFAULT auth.uid();

CREATE INDEX IF NOT EXISTS idx_despensa_user_id ON public.despensa_usuario(user_id);
CREATE INDEX IF NOT EXISTS idx_lista_compras_user_id ON public.lista_compras(user_id);
CREATE INDEX IF NOT EXISTS idx_planeador_user_id ON public.planeador_semanal(user_id);

-- ------------------------------------------------------------------------------
-- 3. FUNCIÓN DE VERIFICACIÓN DE MISMO HOGAR FAMILIAR
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.es_miembro_mismo_hogar(target_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT
    target_user_id IS NULL
    OR target_user_id = auth.uid()
    OR EXISTS (
      SELECT 1
      FROM public.miembros_hogar m1
      INNER JOIN public.miembros_hogar m2 ON m1.hogar_id = m2.hogar_id
      WHERE m1.user_id = auth.uid()
        AND m2.user_id = target_user_id
    );
$$;

-- ------------------------------------------------------------------------------
-- 4. POLÍTICAS RLS PARA HOGARES Y MIEMBROS
-- ------------------------------------------------------------------------------
ALTER TABLE public.hogares ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.miembros_hogar ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "hogares_lectura_autenticados" ON public.hogares;
CREATE POLICY "hogares_lectura_autenticados" ON public.hogares
  FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "hogares_insert_autenticados" ON public.hogares;
CREATE POLICY "hogares_insert_autenticados" ON public.hogares
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "hogares_update_creador" ON public.hogares;
CREATE POLICY "hogares_update_creador" ON public.hogares
  FOR UPDATE USING (auth.uid() = creador_id OR public.es_miembro_mismo_hogar(creador_id));

DROP POLICY IF EXISTS "miembros_hogar_lectura" ON public.miembros_hogar;
CREATE POLICY "miembros_hogar_lectura" ON public.miembros_hogar
  FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "miembros_hogar_insert" ON public.miembros_hogar;
CREATE POLICY "miembros_hogar_insert" ON public.miembros_hogar
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "miembros_hogar_update" ON public.miembros_hogar;
CREATE POLICY "miembros_hogar_update" ON public.miembros_hogar
  FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "miembros_hogar_delete" ON public.miembros_hogar;
CREATE POLICY "miembros_hogar_delete" ON public.miembros_hogar
  FOR DELETE USING (auth.uid() = user_id);

-- ------------------------------------------------------------------------------
-- 5. POLÍTICAS RLS COMPARTIDAS PARA DESPENSA, CARRITO Y PLANEADOR
-- ------------------------------------------------------------------------------
ALTER TABLE public.despensa_usuario ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "despensa_hogar_familiar_all" ON public.despensa_usuario;
CREATE POLICY "despensa_hogar_familiar_all" ON public.despensa_usuario
  FOR ALL
  USING (public.es_miembro_mismo_hogar(user_id))
  WITH CHECK (auth.role() = 'authenticated');

ALTER TABLE public.lista_compras ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "lista_compras_hogar_familiar_all" ON public.lista_compras;
CREATE POLICY "lista_compras_hogar_familiar_all" ON public.lista_compras
  FOR ALL
  USING (public.es_miembro_mismo_hogar(user_id))
  WITH CHECK (auth.role() = 'authenticated');

ALTER TABLE public.planeador_semanal ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "planeador_hogar_familiar_all" ON public.planeador_semanal;
CREATE POLICY "planeador_hogar_familiar_all" ON public.planeador_semanal
  FOR ALL
  USING (public.es_miembro_mismo_hogar(user_id))
  WITH CHECK (auth.role() = 'authenticated');
