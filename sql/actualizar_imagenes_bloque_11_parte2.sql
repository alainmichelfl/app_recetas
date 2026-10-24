-- ============================================================================
-- MIGRACIÓN CULINARIA: BLOQUE 11 PARTE 2 (TACOS DE PESCADO Y QUESADILLAS CON ESPINACA)
-- Jitomate y Cebolla • Fotografías de Estudio Exclusivas
-- ============================================================================

BEGIN;

-- ID 63: Tacos de Pescado a la Plancha
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/tacos_pescado_plancha.jpg'
WHERE id_receta = 63;

-- ID 78: Quesadillas de Huevo con Espinaca
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/quesadillas_huevo_espinaca.jpg'
WHERE id_receta = 78;

COMMIT;
