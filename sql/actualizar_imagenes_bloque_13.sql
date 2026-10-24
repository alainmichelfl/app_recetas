-- ============================================================================
-- MIGRACIÓN CULINARIA: BLOQUE 13 (SNACKS, SEMILLAS, GELATINAS Y BOCADITOS)
-- Jitomate y Cebolla • Fotografías de Estudio Exclusivas
-- ============================================================================

BEGIN;

-- ID 91: Palomitas de Maíz Naturales
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/palomitas_maiz_naturales.jpg'
WHERE id_receta = 91;

-- ID 92: Rollitos de Pechuga de Pavo
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/rollitos_pechuga_pavo.jpg'
WHERE id_receta = 92;

-- ID 93: Almendras Tostadas con Sal de Mar
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/almendras_tostadas_sal_mar.jpg'
WHERE id_receta = 93;

-- ID 94: Gelatina Light de Limón con Yogurt
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/gelatina_light_limon_yogurt.jpg'
WHERE id_receta = 94;

-- ID 96: Bocaditos Energéticos de Avena, Cacahuate y Chocolate Negro
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/bocaditos_energeticos_avena_chocolate.jpg'
WHERE id_receta = 96;

COMMIT;
