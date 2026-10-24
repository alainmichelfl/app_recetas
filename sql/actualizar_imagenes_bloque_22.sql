-- ============================================================================
-- MIGRACIÓN CULINARIA: BLOQUE 22 (SOPAS, QUESADILLAS Y SNACKS FRESCOS)
-- Jitomate y Cebolla • Fotografías de Estudio Exclusivas
-- ============================================================================

BEGIN;

-- ID 46: Sopa Minestrone Reconstituyente
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/sopa_minestrone_reconstituyente.jpg'
WHERE id_receta = 46;

-- ID 48: Quesadillas de Champiñones y Epazote
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/quesadillas_champinones_epazote.jpg'
WHERE id_receta = 48;

-- ID 49: Bowl Nocturno de Quinoa y Huevo Cocido
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/bowl_nocturno_quinoa_huevo.jpg'
WHERE id_receta = 49;

-- ID 50: Hummus Casero con Palitos de Zanahoria
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/hummus_casero_palitos_zanahoria.jpg'
WHERE id_receta = 50;

-- ID 51: Rodajas de Manzana con Crema de Cacahuate
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/rodajas_manzana_crema_cacahuate.jpg'
WHERE id_receta = 51;

COMMIT;
