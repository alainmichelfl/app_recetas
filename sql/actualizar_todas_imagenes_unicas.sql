-- ============================================================================
-- MIGRACIÓN: ACTUALIZACIÓN DEFINITIVA DE IMÁGENES ÚNICAS Y VERIFICADAS (HTTP 200)
-- Base de datos: Supabase public.recetas
-- Resuelve 20 URLs caídas (404) y 28 duplicados en el catálogo completo.
-- Cada imagen fue probada con respuesta HTTP 200 y parámetros optimizados para móvil.
-- ============================================================================

BEGIN;

-- ID 36 (Desayuno): Pancakes de Avena y Plátano
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1506084868230-bb9d95c24759?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 36;

-- ID 38 (Desayuno): Toast de Aguacate con Huevo Poché
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1541519227354-08fa5d50c44d?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 38;

-- ID 39 (Desayuno): Chilaquiles Horneados Fitness
UPDATE public.recetas
SET imagen_url = 'https://plus.unsplash.com/premium_photo-1661776841313-1bd2be380a64?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 39;

-- ID 47 (Cena): Tostadas de Ceviche de Coliflor
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1562707774-553917f561df?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 47;

-- ID 50 (Snack): Hummus Casero con Palitos de Zanahoria
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1577906096429-f73c2c312435?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 50;

-- ID 52 (Snack): Gelatina de Yogurt Griego con Frutos Rojos
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1464965911861-746a04b4bca6?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 52;

-- ID 53 (Snack): Mix Energético de Nueces y Chocolate Amargo
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1514733670139-4d87a1941d55?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 53;

-- ID 57 (Desayuno): Enchiladas Suizas Ligeras
UPDATE public.recetas
SET imagen_url = 'https://plus.unsplash.com/premium_photo-1673018249121-b7618b433466?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 57;

-- ID 58 (Desayuno): Pan Francés Saludable con Frutos Rojos
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1573018943660-502eca08e4b4?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 58;

-- ID 60 (Comida): Poke Bowl de Atún Fresco y Arroz
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1597958792579-bd3517df6399?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 60;

-- ID 61 (Comida): Milanesa de Pollo Horneada
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 61;

-- ID 63 (Comida): Tacos de Pescado a la Plancha
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1782821961510-aa2b6baed210?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 63;

-- ID 66 (Cena): Wrap Ligero de Pollo y Aguacate
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1787472742133-031fc734b96f?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 66;

-- ID 68 (Cena): Rollitos de Jamón de Pavo con Panela
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1781115650881-bc5d55bd31d2?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 68;

-- ID 70 (Snack): Edamames al Vapor con Limón y Tajín
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1730596140741-6cc4963ad816?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 70;

-- ID 71 (Snack): Pudín de Chía y Almendras
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1651256785544-fc012585e6a2?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 71;

-- ID 72 (Snack): Mix Saludable de Semillas y Cacao
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1789546554683-2edf71bcf2e7?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 72;

-- ID 74 (Snack): Smoothie de Cacao y Proteína
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1522065235999-38c8248e5898?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 74;

-- ID 77 (Desayuno): Avena Caliente con Manzana y Almendras
UPDATE public.recetas
SET imagen_url = 'https://plus.unsplash.com/premium_photo-1669559809547-6e4c4fe41371?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 77;

-- ID 79 (Desayuno): Smoothie Bowl de Frutos Rojos
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1577805947697-89e18249d767?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 79;

-- ID 80 (Comida): Pechuga en Salsa Verde con Calabacitas
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1768179669433-bd9d52949c20?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 80;

-- ID 81 (Comida): Atún a la Mexicana
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1622756144420-6877b1b7476e?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 81;

-- ID 83 (Comida): Fajitas de Res con Pimientos
UPDATE public.recetas
SET imagen_url = 'https://plus.unsplash.com/premium_photo-1664478294917-c11274b9ce79?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 83;

-- ID 85 (Cena): Tostadas de Salpicón de Pollo
UPDATE public.recetas
SET imagen_url = 'https://plus.unsplash.com/premium_photo-1673590981774-d9f534e0c617?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 85;

-- ID 86 (Cena): Sopa de Fideos de Calabacita (Zoodles)
UPDATE public.recetas
SET imagen_url = 'https://plus.unsplash.com/premium_photo-1663842680485-45592e97b54b?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 86;

-- ID 87 (Cena): Quesadillas de Flor de Calabaza
UPDATE public.recetas
SET imagen_url = 'https://plus.unsplash.com/premium_photo-1731950424220-17ce9415dcc7?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 87;

-- ID 88 (Cena): Rollitos de Pepino con Atún
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1757715377412-749d66c9c297?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 88;

-- ID 89 (Cena): Tazón de Queso Cottage con Fresas
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1753173301157-8136a70b4178?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 89;

-- ID 90 (Snack): Manzana Asada con Canela
UPDATE public.recetas
SET imagen_url = 'https://plus.unsplash.com/premium_photo-1694336203192-c9e7f2891b95?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 90;

-- ID 92 (Snack): Rollitos de Pechuga de Pavo
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 92;

-- ID 94 (Snack): Gelatina Light de Limón con Yogurt
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1788786877538-2289d3e4cb02?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 94;

-- ID 95 (Cena): Tazón Libre Especial de Quinoa y Vegetales
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1543339308-43e59d6b73a6?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 95;

-- ID 96 (Snack): Bocaditos Energéticos de Avena, Cacahuate y Chocolate Negro
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1678554500191-3885a6fbf8c2?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 96;

-- ID 98 (Comida): Pechuga al Sartén en Salsa Rústica de Jitomate y Cebolla con Arroz
UPDATE public.recetas
SET imagen_url = 'https://plus.unsplash.com/premium_photo-1694141252774-c937d97641da?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 98;

-- ID 99 (Comida): Salmón Sellado con Espárragos Salteados y Aguacate
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1560717845-968823efbee1?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 99;

-- ID 100 (Comida): Pollo al Mojo de Ajo Cítrico con Lentejas Rostizadas y Espinacas
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1598515214211-89d3c73ae83b?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 100;

-- ID 103 (Desayuno): Omelette de Espinacas, Champiñones y Queso Panela
UPDATE public.recetas
SET imagen_url = 'https://plus.unsplash.com/premium_photo-1667807521536-bc35c8d8b64b?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 103;

-- ID 106 (Desayuno): Tostadas de Huevo Pochado con Aguacate y Jitomate Cherry
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1603048588665-791ca8aea617?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 106;

-- ID 107 (Comida): Pechuga de Pollo al Limón con Calabacitas Asadas
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1518492104633-130d0cc84637?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 107;

-- ID 109 (Comida): Tinga de Pollo Casera en Tostadas Horneadas
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1779541900636-6fd6d5ddfe12?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 109;

-- ID 110 (Comida): Picadillo Tradicional de Res con Verduras Mixtas
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1590655367923-fa80b7e61b6c?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 110;

-- ID 111 (Comida): Lentejas Guisadas con Zanahoria y Plátano Macho
UPDATE public.recetas
SET imagen_url = 'https://plus.unsplash.com/premium_photo-1699030868880-d8970ccc146e?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 111;

-- ID 112 (Cena): Tacos de Lechuga con Salpicón de Pollo
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1676976197405-24347416edc1?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 112;

-- ID 116 (Cena): Sopa de Tortilla Tradicional Saludable
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1565086869529-8c7802cca7a0?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 116;

-- ID 118 (Snack): Pepinos Locos Rellenos de Zanahoria y Limón
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1788509814866-e1ddecfa6f0a?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 118;

-- ID 120 (Snack): Brochetas Caprese con Jitomate Cherry y Panela
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1781567502827-3c671d8cae63?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 120;

-- ID 123 (Comida): Pollo al Limón Mediterráneo con Salteado Rústico de Calabacita y Pimiento
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1456404823214-a69ef7a1fae5?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 123;

-- ID 124 (Comida): Salmón Crujiente al Romero con Puré de Camote y Espárragos
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1784571246476-ae530d147e2e?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 124;

COMMIT;

-- Verificación final del total actualizado:
SELECT id_receta, tipo_comida, titulo, imagen_url
FROM public.recetas
WHERE id_receta IN (36, 38, 39, 47, 50, 52, 53, 57, 58, 60, 61, 63, 66, 68, 70, 71, 72, 74, 77, 79, 80, 81, 83, 85, 86, 87, 88, 89, 90, 92, 94, 95, 96, 98, 99, 100, 103, 106, 107, 109, 110, 111, 112, 116, 118, 120, 123, 124)
ORDER BY id_receta;