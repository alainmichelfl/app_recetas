-- ==============================================================================
-- 🍽️ BLOQUE 6: DESACOPLAMIENTO DE PROTEÍNAS, AVENAS Y BEBIDAS EN SUPABASE
-- Proyecto: Jitomate y Cebolla (App Recetas)
-- ==============================================================================

-- 1. 🥩 ID 33: Tostadas Ligeras de Bistec de Res (Desacoplada de Fajitas ID 134)
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/tostadas_bistec_res.jpg'
WHERE id_receta = 33;

-- 2. 🐟 ID 81: Atún a la Mexicana (Desacoplada de Ensalada Fría ID 115)
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/atun_a_la_mexicana.jpg'
WHERE id_receta = 81;

-- 3. 🥣 ID 31: Avena Trasnochada con Manzana y Canela (Tarro de vidrio frío mason jar)
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/avena_trasnochada_manzana.jpg'
WHERE id_receta = 31;

-- 4. 🥤 ID 37: Smoothie Verde Energizante (Debut de beverage-mixology-photographer)
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/smoothie_verde_energizante.jpg'
WHERE id_receta = 37;
