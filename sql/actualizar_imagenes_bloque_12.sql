-- ============================================================================
-- MIGRACIÓN CULINARIA: BLOQUE 12 (GUISADOS VERDES, FAJITAS, SALPICÓN Y FRUTA)
-- Jitomate y Cebolla • Fotografías de Estudio Exclusivas
-- ============================================================================

BEGIN;

-- ID 80: Pechuga en Salsa Verde con Calabacitas
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/pechuga_salsa_verde_calabacitas.jpg'
WHERE id_receta = 80;

-- ID 83: Fajitas de Res con Pimientos
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/fajitas_res_pimientos.jpg'
WHERE id_receta = 83;

-- ID 85: Tostadas de Salpicón de Pollo
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/tostadas_salpicon_pollo.jpg'
WHERE id_receta = 85;

-- ID 89: Tazón de Queso Cottage con Fresas
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/tazon_queso_cottage_fresas.jpg'
WHERE id_receta = 89;

-- ID 90: Manzana Asada con Canela
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/manzana_asada_canela.jpg'
WHERE id_receta = 90;

COMMIT;
