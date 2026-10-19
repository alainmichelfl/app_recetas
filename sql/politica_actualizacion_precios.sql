-- ==============================================================================
-- 🛒 POLÍTICA DE SEGURIDAD RLS PARA PRECIOS DE SUPERMERCADO
-- ==============================================================================
-- Esta política permite que:
-- 1. Cualquier usuario (incluso anónimo o robots con la clave pública/service) 
--    pueda consultar el catálogo general de precios.
-- 2. Los usuarios autenticados que escanean tickets (Crowdsourcing P22) y los 
--    robots automatizados de GitHub Actions puedan actualizar o insertar precios.
-- ==============================================================================

ALTER TABLE public.precios_supermercado ENABLE ROW LEVEL SECURITY;

-- 1. Lectura pública
DROP POLICY IF EXISTS "precios_lectura_publica" ON public.precios_supermercado;
CREATE POLICY "precios_lectura_publica" ON public.precios_supermercado
  FOR SELECT USING (true);

-- 2. Modificación permitida (Crowdsourcing y Robot Nube)
DROP POLICY IF EXISTS "precios_modificar_autenticado" ON public.precios_supermercado;
DROP POLICY IF EXISTS "precios_modificar_todos" ON public.precios_supermercado;

CREATE POLICY "precios_modificar_todos" ON public.precios_supermercado
  FOR ALL USING (true) WITH CHECK (true);
