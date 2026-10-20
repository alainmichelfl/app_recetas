-- ==============================================================================
-- 🍳 MIGRACIÓN: ROTACIÓN Y SEGMENTACIÓN DE "RECIÉN SALIDAS DEL SARTÉN 🔥"
-- Proyecto: Jitomate y Cebolla (App Recetas)
-- ==============================================================================
-- 
-- OBJETIVOS:
-- 1. Agregar la columna 'es_novedad' (BOOLEAN) a public.recetas con índice rápido.
-- 2. Marcar el lote más reciente (IDs >= 102) como 'Recién Salidas del Sartén':
--    es_novedad = true, es_oficial = true, es_publica = true, user_id = NULL.
-- 3. Desvincular 'user_id' de las recetas oficiales creadas en Carga Masiva para
--    que pertenezcan al Catálogo Oficial y no aparezcan en 'Mis Creaciones'.
-- 4. Las recetas históricas (IDs < 102) permanecen como Catálogo Oficial permanente (es_novedad = false).
-- ==============================================================================

BEGIN;

-- 1. AGREGAR COLUMNA 'es_novedad' A public.recetas SI NO EXISTE
ALTER TABLE public.recetas 
  ADD COLUMN IF NOT EXISTS es_novedad BOOLEAN DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_recetas_es_novedad ON public.recetas(es_novedad);

-- 2. ROTACIÓN DEL LOTE ACTIVO:
-- Desmarcar novedades previas (para garantizar que solo el lote actual tenga la insignia)
UPDATE public.recetas 
SET es_novedad = false 
WHERE es_novedad = true;

-- 3. ACTIVAR EL LOTE MÁS RECIENTE COMO NOVEDAD OFICIAL (IDs 102 a 124)
-- Se establece user_id = NULL para que sean oficiales del sistema y no recetas personales
UPDATE public.recetas 
SET 
  es_novedad = true,
  es_oficial = true,
  es_publica = true,
  user_id = NULL
WHERE id_receta >= 102;

-- 4. ASEGURAR QUE LAS RECETAS HISTÓRICAS SEAN OFICIALES DEL RECETARIO
UPDATE public.recetas 
SET 
  es_novedad = false,
  es_oficial = true,
  es_publica = true,
  user_id = NULL
WHERE id_receta < 102 AND (es_oficial = true OR user_id IS NULL);

COMMIT;

-- Verificación de resultados:
SELECT 
  es_novedad, 
  es_oficial, 
  COUNT(*) as total_recetas,
  MIN(id_receta) as id_min,
  MAX(id_receta) as id_max
FROM public.recetas
GROUP BY es_novedad, es_oficial
ORDER BY es_novedad DESC;
