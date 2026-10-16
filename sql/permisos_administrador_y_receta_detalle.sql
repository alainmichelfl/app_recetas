-- ==============================================================================
-- 🐾 PERMISOS DE ADMINISTRADOR, CURACIÓN DE RECETAS Y RECETARIO CANINO
-- Proyecto: Jitomate y Cebolla (App Recetas)
-- ==============================================================================
--
-- ¿QUÉ HACE ESTE SCRIPT?
-- 1. Permite eliminar ingredientes de 'receta_detalle' al borrar una receta (evita error de llave foránea).
-- 2. Asegura permisos de Administrador para alainmichel.fl@gmail.com para eliminar/curar cualquier receta.
-- 3. Abre todas las recetas caninas existentes a la comunidad (es_publica = true) para que todos los lomitos las disfruten.
--
-- INSTRUCCIONES:
-- 1. Abre Supabase: https://supabase.com/dashboard/project/xjfzlthgycczcjbifaty
-- 2. Ve a "SQL Editor" en el menú izquierdo.
-- 3. Crea una "New Query", pega todo este código y presiona "Run".
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. HABILITAR ELIMINACIÓN EN public.receta_detalle
-- ------------------------------------------------------------------------------
ALTER TABLE public.receta_detalle ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "receta_detalle_delete_autenticado" ON public.receta_detalle;
CREATE POLICY "receta_detalle_delete_autenticado" ON public.receta_detalle
  FOR DELETE USING (
    auth.role() = 'authenticated'
  );

-- ------------------------------------------------------------------------------
-- 2. REFORZAR POLÍTICA DE ELIMINACIÓN DE RECETAS PARA EL ADMINISTRADOR
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "recetas_borrar_propia" ON public.recetas;
DROP POLICY IF EXISTS "recetas_borrar_admin" ON public.recetas;

CREATE POLICY "recetas_borrar_admin" ON public.recetas
  FOR DELETE USING (
    -- El usuario puede borrar sus propias recetas
    (auth.uid() IS NOT NULL AND auth.uid() = user_id)
    -- El administrador puede borrar cualquier receta (oficiales, comunitarias o de prueba)
    OR auth.jwt() ->> 'email' = 'alainmichel.fl@gmail.com'
  );

-- ------------------------------------------------------------------------------
-- 3. ABRIR RECETAS CANINAS EXISTENTES A TODA LA COMUNIDAD
-- ------------------------------------------------------------------------------
UPDATE public.recetas
SET es_publica = true
WHERE tipo_comida ILIKE '%canin%' 
   OR tipo_comida ILIKE '%perr%'
   OR titulo ILIKE '%canin%'
   OR titulo ILIKE '%perr%';
