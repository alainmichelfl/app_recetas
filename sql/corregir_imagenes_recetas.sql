-- ==============================================================================
-- 🥑 CORRECCIÓN DE IMÁGENES DE RECETAS EN SUPABASE
-- Proyecto: Jitomate y Cebolla (App Recetas)
-- ==============================================================================
--
-- ¿QUÉ HACE ESTE SCRIPT?
-- 1. Corrige la receta de "Guacamole Rústico con Totopos" (ID 117) sustituyendo la foto
--    de hotcakes por una foto gastronómica de alta resolución de guacamole fresco con totopos.
-- 2. Asigna imágenes HD de Unsplash a recetas que tenían imagen NULL (IDs 95, 96).
-- 3. Sustituye URLs rotas / de placeholder (via.placeholder.com) por fotos reales de comida (IDs 97, 98, 99).
-- 4. Optimiza imágenes para pollo al mojo de ajo (ID 100) y premios perrunos (ID 122).
--
-- INSTRUCCIONES:
-- 1. Abre Supabase: https://supabase.com/dashboard/project/xjfzlthgycczcjbifaty
-- 2. Ve a "SQL Editor" en el menú izquierdo.
-- 3. Crea una "New Query", pega este código y presiona "Run".
-- ==============================================================================

-- 1. 🥑 Guacamole Rústico con Totopos Horneados (Adiós a los hotcakes)
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1680992071073-cb1696ba8d3e?w=800'
WHERE id_receta = 117;

-- 2. 🥗 Tazón Libre Especial de Quinoa y Vegetales (estaba en NULL)
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800'
WHERE id_receta = 95;

-- 3. 🍫 Bocaditos Energéticos de Avena, Cacahuate y Chocolate Negro (estaba en NULL)
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1600868516086-fbcd5a1d7465?w=800'
WHERE id_receta = 96;

-- 4. 🍗 Pechuga a la Plancha con Salsa Rústica y Quinoa (reemplaza placeholder)
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1532550907401-a500c9a57435?w=800'
WHERE id_receta = 97;

-- 5. 🍲 Pechuga al Sartén en Salsa Rústica de Jitomate y Cebolla con Arroz (reemplaza placeholder)
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?w=800'
WHERE id_receta = 98;

-- 6. 🐟 Salmón Sellado con Espárragos Salteados y Aguacate (reemplaza placeholder)
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=800'
WHERE id_receta = 99;

-- 7. 🍗 Pollo al Mojo de Ajo Cítrico con Lentejas Rostizadas y Espinacas
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1598142981503-4c919d75037d?w=800'
WHERE id_receta = 100;

-- 8. 🐶 Bocaditos Crujientes de Calabaza y Zanahoria (Premio perruno seguro)
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=800'
WHERE id_receta = 122;
