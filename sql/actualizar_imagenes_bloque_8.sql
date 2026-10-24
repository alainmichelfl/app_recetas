-- ============================================================================
-- MIGRACIÓN CULINARIA: BLOQUE 8 COMPLETO (DISCORDIANCIAS CRÍTICAS DE OTOÑO)
-- Jitomate y Cebolla • Fotografías de Estudio Exclusivas
-- ============================================================================

BEGIN;

-- ID 141: Chips de Camote Morado y Betabel al Horno (Sustituye bolsas de Cheetos/Cheez-It)
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/chips_camote_morado_betabel.jpg'
WHERE id_receta = 141;

-- ID 140: Compota Tibia de Manzana y Guayaba con Canela (Sustituye cupcake amarillo)
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/compota_manzana_guayaba_canela.jpg'
WHERE id_receta = 140;

-- ID 137: Camote Horneado Relleno de Pollo Deshebrado (Sustituye ensalada de sandía con camarón)
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/camote_horneado_relleno_pollo.jpg'
WHERE id_receta = 137;

-- ID 138: Crema Ligera de Calabaza con Hongos Salteados (Sustituye filete de salmón sellado)
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/crema_calabaza_hongos_salteados.jpg'
WHERE id_receta = 138;

COMMIT;
