-- ============================================================================
-- MIGRACIÓN CULINARIA: BLOQUE 21 (PLATOS FUERTES, PESCADOS Y PASTAS)
-- Jitomate y Cebolla • Fotografías de Estudio Exclusivas
-- ============================================================================

BEGIN;

-- ID 40: Pechuga de Pollo al Limón y Romero
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/pechuga_pollo_limon_romero.jpg'
WHERE id_receta = 40;

-- ID 41: Salmón al Horno con Quinoa
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/salmon_horno_quinoa.jpg'
WHERE id_receta = 41;

-- ID 43: Ensalada César con Pollo a la Parrilla
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/ensalada_cesar_pollo_parrilla.jpg'
WHERE id_receta = 43;

-- ID 44: Pasta Integral al Pesto con Tomate Cherry
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/pasta_integral_pesto_cherry.jpg'
WHERE id_receta = 44;

-- ID 45: Atún Sellado con Costra de Ajonjolí
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/atun_sellado_costra_ajonjoli.jpg'
WHERE id_receta = 45;

COMMIT;
