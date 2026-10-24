-- ============================================================================
-- MIGRACIÓN CULINARIA: BLOQUE 23 (SNACKS, PAN FRANCÉS Y POKE BOWLS)
-- Jitomate y Cebolla • Fotografías de Estudio Exclusivas
-- ============================================================================

BEGIN;

-- ID 53: Mix Energético de Nueces y Chocolate Amargo
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/mix_energetico_nueces_chocolate.jpg'
WHERE id_receta = 53;

-- ID 54: Galletas de Avena y Plátano al Microondas
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/galletas_avena_platano_microondas.jpg'
WHERE id_receta = 54;

-- ID 56: Tazón de Yogurt con Chía y Mango
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/tazon_yogurt_chia_mango.jpg'
WHERE id_receta = 56;

-- ID 58: Pan Francés Saludable con Frutos Rojos
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/pan_frances_saludable_frutos_rojos.jpg'
WHERE id_receta = 58;

-- ID 60: Poke Bowl de Atún Fresco y Arroz
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/poke_bowl_atun_fresco_arroz.jpg'
WHERE id_receta = 60;

COMMIT;
