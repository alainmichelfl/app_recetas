-- ==============================================================================
-- 🥘 RESTAURACIÓN TOTAL DEL CATÁLOGO DE RECETAS E IMAGEN DE PICADILLO
-- Proyecto: Jitomate y Cebolla (App Recetas)
-- ==============================================================================
--
-- ¿QUÉ HACE ESTE SCRIPT?
-- 1. Corrige la imagen de la receta #110 (Picadillo Tradicional de Res con Verduras)
--    reemplazando la foto errónea de ensalada por una foto gastronómica HD
--    de picadillo de carne molida en sartén con verduras y chiles.
-- 2. Asegura que todas las recetas del catálogo base (70 recetas predeterminadas)
--    estén marcadas como oficiales (es_oficial = true) y públicas (es_publica = true).
-- 3. Elimina cualquier política restrictiva de Row Level Security (RLS) en 'recetas'
--    que estuviera ocultando las recetas base al iniciar sesión.
-- 4. Establece una política de lectura universal ('recetas_lectura_todas')
--    que garantiza que todos los usuarios (autenticados y anónimos) puedan
--    ver el catálogo completo (92+ recetas) en todas las categorías.
--
-- INSTRUCCIONES:
-- 1. Abre Supabase: https://supabase.com/dashboard/project/xjfzlthgycczcjbifaty
-- 2. Ve a "SQL Editor" en el menú izquierdo.
-- 3. Crea una "New Query", pega todo este código y presiona "Run".
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. CORREGIR IMAGEN DE PICADILLO TRADICIONAL (#110)
-- ------------------------------------------------------------------------------
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1590655367923-fa80b7e61b6c?w=800'
WHERE id_receta = 110;

-- ------------------------------------------------------------------------------
-- 2. ASEGURAR QUE LAS RECETAS BASE SEAN OFICIALES Y PÚBLICAS
-- ------------------------------------------------------------------------------
UPDATE public.recetas
SET es_oficial = true, es_publica = true
WHERE user_id IS NULL;

-- ------------------------------------------------------------------------------
-- 3. LIMPIAR Y UNIFICAR POLÍTICAS RLS DE LECTURA EN public.recetas
-- ------------------------------------------------------------------------------
ALTER TABLE public.recetas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "recetas_lectura_publica" ON public.recetas;
DROP POLICY IF EXISTS "recetas_lectura_unificada" ON public.recetas;
DROP POLICY IF EXISTS "recetas_select_propio" ON public.recetas;
DROP POLICY IF EXISTS "recetas_select_todas" ON public.recetas;
DROP POLICY IF EXISTS "recetas_lectura_todas" ON public.recetas;
DROP POLICY IF EXISTS "Permitir lectura publica de recetas" ON public.recetas;

-- Todos los usuarios (anónimos y autenticados) pueden leer el recetario completo
CREATE POLICY "recetas_lectura_todas" ON public.recetas
  FOR SELECT USING (true);

-- Permite insertar recetas a usuarios autenticados
DROP POLICY IF EXISTS "recetas_insert_autenticado" ON public.recetas;
CREATE POLICY "recetas_insert_autenticado" ON public.recetas
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Permite modificar únicamente al creador de la receta o al administrador
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

-- Permite borrar únicamente al creador de la receta o al administrador
DROP POLICY IF EXISTS "recetas_borrar_admin" ON public.recetas;
DROP POLICY IF EXISTS "recetas_borrar_propia" ON public.recetas;
CREATE POLICY "recetas_borrar_admin" ON public.recetas
  FOR DELETE USING (
    (auth.uid() IS NOT NULL AND auth.uid() = user_id)
    OR auth.jwt() ->> 'email' = 'alainmichel.fl@gmail.com'
  );
