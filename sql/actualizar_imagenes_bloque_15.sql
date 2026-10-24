-- ============================================================================
-- MIGRACIÓN CULINARIA: BLOQUE 15 (DESAYUNOS TRADICIONALES DE COMAL)
-- Jitomate y Cebolla • Fotografías de Estudio Exclusivas
-- ============================================================================

BEGIN;

-- ID 102: Chilaquiles Verdes Ligeros con Pollo Deshebrado
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/chilaquiles_verdes_ligeros_pollo.jpg'
WHERE id_receta = 102;

-- ID 103: Omelette de Espinacas, Champiñones y Queso Panela
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/omelette_espinacas_champinones_panela.jpg'
WHERE id_receta = 103;

-- ID 105: Bowl de Avena Cremosa con Manzana y Canela
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/bowl_avena_cremosa_manzana_canela.jpg'
WHERE id_receta = 105;

-- ID 106: Tostadas de Huevo Pochado con Aguacate y Jitomate Cherry
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/tostadas_huevo_pochado_aguacate.jpg'
WHERE id_receta = 106;

COMMIT;
