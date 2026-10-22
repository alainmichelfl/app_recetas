-- ============================================================================
-- MIGRACIÓN CULINARIA: BLOQUE 7 COMPLETO (4 PLATILLOS DE AUTOR)
-- Jitomate y Cebolla • Fotografías de Estudio Exclusivas
-- ============================================================================

BEGIN;

-- ID 82: Ensalada de Pasta Fría con Pollo
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/ensalada_pasta_fria_pollo.jpg'
WHERE id_receta = 82;

-- ID 42: Tacos Veganos de Lentejas al Pastor
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/tacos_lentejas_al_pastor.jpg'
WHERE id_receta = 42;

-- ID 119: Pudín de Chía con Leche de Almendras y Frutos Rojos
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/pudin_chia_frutos_rojos.jpg'
WHERE id_receta = 119;

-- ID 59: Licuado de Avena, Plátano y Crema de Maní
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/licuado_avena_platano_mani.jpg'
WHERE id_receta = 59;

COMMIT;
