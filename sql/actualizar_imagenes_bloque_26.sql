-- ============================================================================
-- MIGRACIÓN CULINARIA: BLOQUE 26 (CIERRE DEL CATÁLOGO 100% OFICIAL - 114 RECETAS)
-- Jitomate y Cebolla • Fotografías de Estudio Exclusivas
-- ============================================================================

BEGIN;

-- ID 75: Toast de Crema de Cacahuate y Plátano
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/toast_crema_cacahuate_platano.jpg'
WHERE id_receta = 75;

-- ID 77: Avena Caliente con Manzana y Almendras
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/avena_caliente_manzana_almendras.jpg'
WHERE id_receta = 77;

-- ID 84: Ceviche de Soya
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/ceviche_de_soya.jpg'
WHERE id_receta = 84;

COMMIT;
