-- ============================================================================
-- MIGRACIÓN CULINARIA: BLOQUE 19 (CENAS LIGERAS, SOPAS Y SALTEADOS)
-- Jitomate y Cebolla • Fotografías de Estudio Exclusivas
-- ============================================================================

BEGIN;

-- ID 134: Fajitas Express de Pechuga con Hongos y Manzana
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/fajitas_express_pechuga_hongos_manzana.jpg'
WHERE id_receta = 134;

-- ID 135: Sopa Ligera de Hongos Silvestres y Epazote
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/sopa_ligera_hongos_epazote.jpg'
WHERE id_receta = 135;

-- ID 136: Ensalada Nocturna de Manzana, Betabel y Panela
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/ensalada_nocturna_manzana_betabel_panela.jpg'
WHERE id_receta = 136;

-- ID 139: Salteado Oriental de Calabaza de Castilla y Pollo
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/salteado_oriental_calabaza_pollo.jpg'
WHERE id_receta = 139;

-- ID 143: Gajos de Manzana Dorada con Requesón y Nuez
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/gajos_manzana_dorada_requeson_nuez.jpg'
WHERE id_receta = 143;

COMMIT;
