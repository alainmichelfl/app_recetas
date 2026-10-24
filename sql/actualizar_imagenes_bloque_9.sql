-- ============================================================================
-- MIGRACIÓN CULINARIA: BLOQUE 9 COMPLETO (SOPAS, TOSTADAS Y BOTANAS LIGERAS)
-- Jitomate y Cebolla • Fotografías de Estudio Exclusivas
-- ============================================================================

BEGIN;

-- ID 47: Tostadas de Ceviche de Coliflor (Sustituye ceviche de pescado crudo)
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/tostadas_ceviche_coliflor.jpg'
WHERE id_receta = 47;

-- ID 86: Sopa de Fideos de Calabacita (Zoodles) (Sustituye plato plano seco con sombrero)
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/sopa_fideos_calabacita_zoodles.jpg'
WHERE id_receta = 86;

-- ID 142: Pepitas de Calabaza Tostadas al Comal con Canela (Sustituye taza de té de lavanda)
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/pepitas_calabaza_tostadas_comal.jpg'
WHERE id_receta = 142;

-- ID 144: Gajos de Mandarina con Salpicado de Canela y Pepitas (Sustituye huacal de naranjas crudas)
UPDATE public.recetas
SET imagen_url = 'https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/gajos_mandarina_canela_pepitas.jpg'
WHERE id_receta = 144;

COMMIT;
