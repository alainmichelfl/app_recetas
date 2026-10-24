-- ============================================================================
-- MIGRACIÓN CULINARIA: BLOQUE 16 (CREMAS, ENSALADAS Y BOTANAS LIGERAS)
-- Jitomate y Cebolla • Fotografías de Estudio Exclusivas
-- ============================================================================

BEGIN;

-- ID 113: Crema Ligera de Calabacita con Queso Panela
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/crema_ligera_calabacita_panela.jpg'
WHERE id_receta = 113;

-- ID 115: Ensalada Fresca de Atún con Jitomate y Aguacate
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/ensalada_fresca_atun_aguacate.jpg'
WHERE id_receta = 115;

-- ID 117: Guacamole Rústico con Totopos Horneados
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/guacamole_rustico_totopos_horneados.jpg'
WHERE id_receta = 117;

-- ID 120: Brochetas Caprese con Jitomate Cherry y Panela
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/brochetas_caprese_cherry_panela.jpg'
WHERE id_receta = 120;

COMMIT;
