-- ============================================================================
-- MIGRACIÓN CULINARIA: BLOQUE 17 (GOURMET DE OTOÑO Y PESCADOS)
-- Jitomate y Cebolla • Fotografías de Estudio Exclusivas
-- ============================================================================

BEGIN;

-- ID 121: Manzana en Rebanadas con Crema de Cacahuate y Canela
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/manzana_rebanadas_cacahuate_canela.jpg'
WHERE id_receta = 121;

-- ID 123: Pollo al Limón Mediterráneo con Salteado Rústico de Calabacita y Pimiento
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/pollo_limon_mediterraneo_calabacita.jpg'
WHERE id_receta = 123;

-- ID 124: Salmón Crujiente al Romero con Puré de Camote y Espárragos
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/salmon_crujiente_romero_pure_camote.jpg'
WHERE id_receta = 124;

-- ID 126: Pancakes de Calabaza de Castilla Especiada
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/pancakes_calabaza_castilla_especiada.jpg'
WHERE id_receta = 126;

COMMIT;
