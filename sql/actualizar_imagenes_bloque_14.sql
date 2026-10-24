-- ============================================================================
-- MIGRACIÓN CULINARIA: BLOQUE 14 (BOWLS Y PLANCHA RÚSTICA)
-- Jitomate y Cebolla • Fotografías de Estudio Exclusivas
-- ============================================================================

BEGIN;

-- ID 95: Tazón Libre Especial de Quinoa y Vegetales
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/tazon_libre_quinoa_vegetales.jpg'
WHERE id_receta = 95;

-- ID 97: Pechuga a la Plancha con Salsa Rústica y Quinoa
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/pechuga_plancha_salsa_rustica_quinoa.jpg'
WHERE id_receta = 97;

-- ID 98: Pechuga al Sartén en Salsa Rústica de Jitomate y Cebolla con Arroz
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/pechuga_sarten_salsa_rustica_arroz.jpg'
WHERE id_receta = 98;

-- ID 99: Salmón Sellado con Espárragos Salteados y Aguacate
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/salmon_sellado_esparragos_aguacate.jpg'
WHERE id_receta = 99;

-- ID 100: Pollo al Mojo de Ajo Cítrico con Lentejas Rostizadas y Espinacas
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/pollo_mojo_ajo_citrico_lentejas.jpg'
WHERE id_receta = 100;

COMMIT;
