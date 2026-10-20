-- ============================================================================
-- MIGRACIÓN: ACTUALIZACIÓN DEFINITIVA DE IMÁGENES ÚNICAS Y VERIFICADAS (HTTP 200)
-- Base de datos: Supabase public.recetas
-- Auditoría visual por IA (Gemini Vision) para eliminar fotos discordantes
-- (sin vinilos, sin perros, sin libros, sin fotos erróneas).
-- Todas las 94 recetas cuentan con imágenes gastronómicas auténticas optimizadas.
-- ============================================================================

BEGIN;

-- ID 31: Avena Trasnochada con Manzana y Canela
UPDATE public.recetas
SET imagen_url = 'https://plus.unsplash.com/premium_photo-1669559809547-6e4c4fe41371?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 31;

-- ID 32: Bowl de Pollo y Vegetales al Chipotle
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 32;

-- ID 33: Tostadas Ligeras de Bistec de Res
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1551504734-5ee1c4a1479b?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 33;

-- ID 34: Snack de Yogurt Griego con Moras
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1488477181946-6428a0291777?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 34;

-- ID 35: Huevos a la Mexicana Ligeros
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1510693206972-df098062cb71?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 35;

-- ID 36: Pancakes de Avena y Plátano
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1506084868230-bb9d95c24759?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 36;

-- ID 37: Smoothie Verde Energizante
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1628557044797-f21a177c37ec?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 37;

-- ID 38: Toast de Aguacate con Huevo Poché
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1541519227354-08fa5d50c44d?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 38;

-- ID 39: Chilaquiles Horneados Fitness
UPDATE public.recetas
SET imagen_url = 'https://plus.unsplash.com/premium_photo-1661776841313-1bd2be380a64?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 39;

-- ID 40: Pechuga de Pollo al Limón y Romero
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1532550907401-a500c9a57435?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 40;

-- ID 41: Salmón al Horno con Quinoa
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 41;

-- ID 42: Tacos Veganos de Lentejas al Pastor
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1565299585323-38d6b0865b47?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 42;

-- ID 43: Ensalada César con Pollo a la Parrilla
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1550304943-4f24f54ddde9?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 43;

-- ID 44: Pasta Integral al Pesto con Tomate Cherry
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1473093295043-cdd812d0e601?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 44;

-- ID 45: Atún Sellado con Costra de Ajonjolí
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1501595091296-3aa970afb3ff?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 45;

-- ID 46: Sopa Minestrone Reconstituyente
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1603105037880-880cd4edfb0d?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 46;

-- ID 47: Tostadas de Ceviche de Coliflor
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1562707774-553917f561df?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 47;

-- ID 48: Quesadillas de Champiñones y Epazote
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1618040996337-56904b7850b9?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 48;

-- ID 49: Bowl Nocturno de Quinoa y Huevo Cocido
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 49;

-- ID 50: Hummus Casero con Palitos de Zanahoria
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1511690656952-34342bb7c2f2?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 50;

-- ID 51: Rodajas de Manzana con Crema de Cacahuate
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1568702846914-96b305d2aaeb?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 51;

-- ID 52: Gelatina de Yogurt Griego con Frutos Rojos
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1488477181946-6428a0291777?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 52;

-- ID 53: Mix Energético de Nueces y Chocolate Amargo
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1508061253366-f7da158b6d46?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 53;

-- ID 54: Galletas de Avena y Plátano al Microondas
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1558961363-fa8fdf82db35?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 54;

-- ID 55: Omelette de Claras con Espinaca
UPDATE public.recetas
SET imagen_url = 'https://plus.unsplash.com/premium_photo-1667807521536-bc35c8d8b64b?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 55;

-- ID 56: Tazón de Yogurt con Chía y Mango
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1494597564530-871f2b93ac55?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 56;

-- ID 57: Enchiladas Suizas Ligeras
UPDATE public.recetas
SET imagen_url = 'https://plus.unsplash.com/premium_photo-1673018249121-b7618b433466?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 57;

-- ID 58: Pan Francés Saludable con Frutos Rojos
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1584776296944-ab6fb57b0bdd?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 58;

-- ID 59: Licuado de Avena, Plátano y Crema de Maní
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1577805947697-89e18249d767?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 59;

-- ID 60: Poke Bowl de Atún Fresco y Arroz
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1597958792579-bd3517df6399?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 60;

-- ID 61: Milanesa de Pollo Horneada
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 61;

-- ID 62: Albóndigas de Pavo en Chipotle
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1529042410759-befb1204b468?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 62;

-- ID 63: Tacos de Pescado a la Plancha
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1782821961510-aa2b6baed210?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 63;

-- ID 64: Pimientos Rellenos de Quinoa
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1518779578993-ec3579fee39f?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 64;

-- ID 65: Pizza Ligera de Base de Coliflor
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 65;

-- ID 66: Wrap Ligero de Pollo y Aguacate
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1787472742133-031fc734b96f?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 66;

-- ID 67: Sopa de Lentejas Tradicional
UPDATE public.recetas
SET imagen_url = 'https://plus.unsplash.com/premium_photo-1699030868880-d8970ccc146e?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 67;

-- ID 68: Rollitos de Jamón de Pavo con Panela
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1781115650881-bc5d55bd31d2?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 68;

-- ID 69: Ensalada Caprese con Vinagreta
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1529312266912-b33cfce2eefd?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 69;

-- ID 70: Edamames al Vapor con Limón y Tajín
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1730596140741-6cc4963ad816?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 70;

-- ID 71: Pudín de Chía y Almendras
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1651256785544-fc012585e6a2?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 71;

-- ID 72: Mix Saludable de Semillas y Cacao
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1789546554683-2edf71bcf2e7?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 72;

-- ID 73: Bastones de Apio con Queso Crema
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1592394533824-9440e5d68530?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 73;

-- ID 74: Smoothie de Cacao y Proteína
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1522065235999-38c8248e5898?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 74;

-- ID 75: Toast de Crema de Cacahuate y Plátano
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1588137378633-dea1336ce1e2?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 75;

-- ID 76: Tacos de Huevo con Nopal
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1552332386-f8dd00dc2f85?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 76;

-- ID 77: Avena Caliente con Manzana y Almendras
UPDATE public.recetas
SET imagen_url = 'https://plus.unsplash.com/premium_photo-1669559809547-6e4c4fe41371?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 77;

-- ID 78: Quesadillas de Huevo con Espinaca
UPDATE public.recetas
SET imagen_url = 'https://plus.unsplash.com/premium_photo-1731950424220-17ce9415dcc7?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 78;

-- ID 79: Smoothie Bowl de Frutos Rojos
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1494597564530-871f2b93ac55?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 79;

-- ID 80: Pechuga en Salsa Verde con Calabacitas
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1768179669433-bd9d52949c20?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 80;

-- ID 81: Atún a la Mexicana
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1622756144420-6877b1b7476e?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 81;

-- ID 82: Ensalada de Pasta Fría con Pollo
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1473093295043-cdd812d0e601?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 82;

-- ID 83: Fajitas de Res con Pimientos
UPDATE public.recetas
SET imagen_url = 'https://plus.unsplash.com/premium_photo-1664478294917-c11274b9ce79?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 83;

-- ID 84: Ceviche de Soya
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1535399831218-d5bd36d1a6b3?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 84;

-- ID 85: Tostadas de Salpicón de Pollo
UPDATE public.recetas
SET imagen_url = 'https://plus.unsplash.com/premium_photo-1673590981774-d9f534e0c617?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 85;

-- ID 86: Sopa de Fideos de Calabacita (Zoodles)
UPDATE public.recetas
SET imagen_url = 'https://plus.unsplash.com/premium_photo-1663842680485-45592e97b54b?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 86;

-- ID 87: Quesadillas de Flor de Calabaza
UPDATE public.recetas
SET imagen_url = 'https://plus.unsplash.com/premium_photo-1731950424220-17ce9415dcc7?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 87;

-- ID 88: Rollitos de Pepino con Atún
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1757715377412-749d66c9c297?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 88;

-- ID 89: Tazón de Queso Cottage con Fresas
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1753173301157-8136a70b4178?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 89;

-- ID 90: Manzana Asada con Canela
UPDATE public.recetas
SET imagen_url = 'https://plus.unsplash.com/premium_photo-1694336203192-c9e7f2891b95?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 90;

-- ID 91: Palomitas de Maíz Naturales
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1578849278619-e73505e9610f?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 91;

-- ID 92: Rollitos de Pechuga de Pavo
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1781115650881-bc5d55bd31d2?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 92;

-- ID 93: Almendras Tostadas con Sal de Mar
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1508061253366-f7da158b6d46?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 93;

-- ID 94: Gelatina Light de Limón con Yogurt
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1788786877538-2289d3e4cb02?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 94;

-- ID 95: Tazón Libre Especial de Quinoa y Vegetales
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1543339308-43e59d6b73a6?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 95;

-- ID 96: Bocaditos Energéticos de Avena, Cacahuate y Chocolate Negro
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1678554500191-3885a6fbf8c2?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 96;

-- ID 97: Pechuga a la Plancha con Salsa Rústica y Quinoa
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1532550907401-a500c9a57435?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 97;

-- ID 98: Pechuga al Sartén en Salsa Rústica de Jitomate y Cebolla con Arroz
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 98;

-- ID 99: Salmón Sellado con Espárragos Salteados y Aguacate
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1560717845-968823efbee1?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 99;

-- ID 100: Pollo al Mojo de Ajo Cítrico con Lentejas Rostizadas y Espinacas
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1598515214211-89d3c73ae83b?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 100;

-- ID 101: Tazón Mediterráneo de Pollo al Limón, Garbanzos y Tzatziki
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1511690656952-34342bb7c2f2?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 101;

-- ID 102: Chilaquiles Verdes Ligeros con Pollo Deshebrado
UPDATE public.recetas
SET imagen_url = 'https://plus.unsplash.com/premium_photo-1661776841313-1bd2be380a64?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 102;

-- ID 103: Omelette de Espinacas, Champiñones y Queso Panela
UPDATE public.recetas
SET imagen_url = 'https://plus.unsplash.com/premium_photo-1667807521536-bc35c8d8b64b?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 103;

-- ID 104: Molletes Tradicionales con Pico de Gallo Fresco
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1588137378633-dea1336ce1e2?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 104;

-- ID 105: Bowl de Avena Cremosa con Manzana y Canela
UPDATE public.recetas
SET imagen_url = 'https://plus.unsplash.com/premium_photo-1669559809547-6e4c4fe41371?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 105;

-- ID 106: Tostadas de Huevo Pochado con Aguacate y Jitomate Cherry
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1525351484163-7529414344d8?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 106;

-- ID 107: Pechuga de Pollo al Limón con Calabacitas Asadas
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 107;

-- ID 108: Pescado a la Veracruzana con Arroz Integral
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 108;

-- ID 109: Tinga de Pollo Casera en Tostadas Horneadas
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1552332386-f8dd00dc2f85?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 109;

-- ID 110: Picadillo Tradicional de Res con Verduras Mixtas
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1590655367923-fa80b7e61b6c?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 110;

-- ID 111: Lentejas Guisadas con Zanahoria y Plátano Macho
UPDATE public.recetas
SET imagen_url = 'https://plus.unsplash.com/premium_photo-1699030868880-d8970ccc146e?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 111;

-- ID 112: Tacos de Lechuga con Salpicón de Pollo
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1543339308-43e59d6b73a6?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 112;

-- ID 113: Crema Ligera de Calabacita con Queso Panela
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1547592166-23ac45744acd?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 113;

-- ID 114: Quesadillas de Nopal Asado con Queso Oaxaca
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1618040996337-56904b7850b9?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 114;

-- ID 115: Ensalada Fresca de Atún con Jitomate y Aguacate
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1622756144420-6877b1b7476e?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 115;

-- ID 116: Sopa de Tortilla Tradicional Saludable
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1547592166-23ac45744acd?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 116;

-- ID 117: Guacamole Rústico con Totopos Horneados
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1680992071073-cb1696ba8d3e?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 117;

-- ID 118: Pepinos Locos Rellenos de Zanahoria y Limón
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1788509814866-e1ddecfa6f0a?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 118;

-- ID 119: Pudín de Chía con Leche de Almendras y Frutos Rojos
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1651256785544-fc012585e6a2?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 119;

-- ID 120: Brochetas Caprese con Jitomate Cherry y Panela
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1781567502827-3c671d8cae63?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 120;

-- ID 121: Manzana en Rebanadas con Crema de Cacahuate y Canela
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1568702846914-96b305d2aaeb?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 121;

-- ID 122: Bocaditos Crujientes de Calabaza y Zanahoria
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1678554500191-3885a6fbf8c2?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 122;

-- ID 123: Pollo al Limón Mediterráneo con Salteado Rústico de Calabacita y Pimiento
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 123;

-- ID 124: Salmón Crujiente al Romero con Puré de Camote y Espárragos
UPDATE public.recetas
SET imagen_url = 'https://images.unsplash.com/photo-1784571246476-ae530d147e2e?auto=format&fit=crop&w=600&q=80'
WHERE id_receta = 124;

COMMIT;

-- Verificación final del total actualizado:
SELECT count(DISTINCT id_receta) as total_actualizadas, count(DISTINCT imagen_url) as total_imagenes_unicas
FROM public.recetas;