-- ============================================================================
-- MIGRACIÓN CULINARIA: BLOQUE 25 (ENSALADAS, EDAMAMES, PUDÍN Y SMOOTHIES)
-- Jitomate y Cebolla • Fotografías de Estudio Exclusivas
-- ============================================================================

BEGIN;

-- ID 69: Ensalada Caprese con Vinagreta
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/ensalada_caprese_vinagreta.jpg'
WHERE id_receta = 69;

-- ID 70: Edamames al Vapor con Limón y Tajín
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/edamames_vapor_limon_tajin.jpg'
WHERE id_receta = 70;

-- ID 71: Pudín de Chía y Almendras
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/pudin_chia_almendras.jpg'
WHERE id_receta = 71;

-- ID 72: Mix Saludable de Semillas y Cacao
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/mix_saludable_semillas_cacao.jpg'
WHERE id_receta = 72;

-- ID 74: Smoothie de Cacao y Proteína
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/smoothie_cacao_proteina.jpg'
WHERE id_receta = 74;

COMMIT;
