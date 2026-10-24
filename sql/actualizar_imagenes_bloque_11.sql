-- ============================================================================
-- MIGRACIÓN CULINARIA: BLOQUE 11 PARCIAL (MILANESA HORNEADA Y ALBÓNDIGAS EN CHIPOTLE)
-- Jitomate y Cebolla • Fotografías de Estudio Exclusivas
-- ============================================================================

BEGIN;

-- ID 61: Milanesa de Pollo Horneada (Sustituye pollo frito tipo KFC)
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/milanesa_pollo_horneada.jpg'
WHERE id_receta = 61;

-- ID 62: Albóndigas de Pavo en Chipotle (Sustituye albóndigas de cóctel secas)
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/albondigas_pavo_chipotle.jpg'
WHERE id_receta = 62;

COMMIT;
