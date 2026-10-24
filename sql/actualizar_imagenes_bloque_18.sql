-- ============================================================================
-- MIGRACIÓN CULINARIA: BLOQUE 18 (SARTENES DE TEMPORADA)
-- Jitomate y Cebolla • Fotografías de Estudio Exclusivas
-- ============================================================================

BEGIN;

-- ID 127: Huevos Revueltos con Hongos y Betabel Salteado
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/huevos_revueltos_hongos_betabel.jpg'
WHERE id_receta = 127;

-- ID 130: Crema Aterciopelada de Calabaza de Castilla Rostizada
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/crema_aterciopelada_calabaza_rostizada.jpg'
WHERE id_receta = 130;

-- ID 131: Pechuga al Sartén con Glaseado de Mandarina y Camote
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/pechuga_sarten_glaseado_mandarina_camote.jpg'
WHERE id_receta = 131;

-- ID 132: Ensalada Tibia de Lentejas con Betabel y Hongos
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/ensalada_tibia_lentejas_betabel_hongos.jpg'
WHERE id_receta = 132;

COMMIT;
