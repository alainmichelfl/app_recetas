-- ============================================================================
-- MIGRACIÓN CULINARIA: BLOQUE 24 (LIGEROS, PIZZA, WRAPS Y LENTEJAS)
-- Jitomate y Cebolla • Fotografías de Estudio Exclusivas
-- ============================================================================

BEGIN;

-- ID 64: Pimientos Rellenos de Quinoa
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/pimientos_rellenos_quinoa.jpg'
WHERE id_receta = 64;

-- ID 65: Pizza Ligera de Base de Coliflor
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/pizza_ligera_base_coliflor.jpg'
WHERE id_receta = 65;

-- ID 66: Wrap Ligero de Pollo y Aguacate
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/wrap_ligero_pollo_aguacate.jpg'
WHERE id_receta = 66;

-- ID 67: Sopa de Lentejas Tradicional
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/sopa_lentejas_tradicional.jpg'
WHERE id_receta = 67;

-- ID 68: Rollitos de Jamón de Pavo con Panela
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/rollitos_jamon_pavo_panela.jpg'
WHERE id_receta = 68;

COMMIT;
