-- ============================================================================
-- MIGRACIÓN CULINARIA: BLOQUE 10 COMPLETO (PLATOS FUERTES TRADICIONALES)
-- Jitomate y Cebolla • Fotografías de Estudio Exclusivas
-- ============================================================================

BEGIN;

-- ID 109: Tinga de Pollo Casera en Tostadas Horneadas (Sustituye tacos de suadero)
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/tinga_pollo_tostadas_horneadas.jpg'
WHERE id_receta = 109;

-- ID 110: Picadillo Tradicional de Res con Verduras Mixtas (Sustituye tazón árabe de cordero)
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/picadillo_tradicional_res.jpg'
WHERE id_receta = 110;

-- ID 108: Pescado a la Veracruzana con Arroz Integral (Sustituye salmón sobre zoodles)
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/pescado_veracruzana_arroz_integral.jpg'
WHERE id_receta = 108;

-- ID 57: Enchiladas Suizas Ligeras (Sustituye canelón francés)
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/enchiladas_suizas_ligeras.jpg'
WHERE id_receta = 57;

COMMIT;
