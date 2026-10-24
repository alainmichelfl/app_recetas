-- ============================================================================
-- MIGRACIÓN CULINARIA: BLOQUE 20 (DESAYUNOS CLÁSICOS Y BOWLS)
-- Jitomate y Cebolla • Fotografías de Estudio Exclusivas
-- ============================================================================

BEGIN;

-- ID 32: Bowl de Pollo y Vegetales al Chipotle
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/bowl_pollo_vegetales_chipotle.jpg'
WHERE id_receta = 32;

-- ID 34: Snack de Yogurt Griego con Moras
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/snack_yogurt_griego_moras.jpg'
WHERE id_receta = 34;

-- ID 35: Huevos a la Mexicana Ligeros
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/huevos_a_la_mexicana_ligeros.jpg'
WHERE id_receta = 35;

-- ID 36: Pancakes de Avena y Plátano
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/pancakes_avena_platano.jpg'
WHERE id_receta = 36;

-- ID 38: Toast de Aguacate con Huevo Poché
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/toast_aguacate_huevo_poche.jpg'
WHERE id_receta = 38;

COMMIT;
