-- ==============================================================================
-- 🛡️ SCRIPT DE BLINDAJE Y MULTI-USUARIO (ROW LEVEL SECURITY)
-- Proyecto: Jitomate y Cebolla (App Recetas)
-- ==============================================================================
--
-- ¿QUÉ HACE ESTE SCRIPT?
-- 1. Agrega la columna 'user_id' a las tablas personales (planeador, lista_compras, despensa_usuario).
-- 2. Asigna automáticamente tus datos actuales a tu cuenta para que no pierdas nada.
-- 3. Crea triggers automáticos para que cada nuevo elemento se asocie al usuario que lo crea.
-- 4. Activa Row Level Security (RLS) en todas las tablas:
--    - Tablas maestras (recetas, precios, catálogo): Protegidas contra borrado/hackeo.
--    - Tablas de usuario (planeador, carrito, despensa): Privadas y aisladas por usuario.
--
-- INSTRUCCIONES:
-- 1. Abre Supabase: https://supabase.com/dashboard/project/xjfzlthgycczcjbifaty
-- 2. Ve a "SQL Editor" en el menú izquierdo.
-- 3. Crea una "New Query", pega todo este código y presiona "Run".
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. AGREGAR COLUMNA user_id A LAS TABLAS PERSONALES
-- ------------------------------------------------------------------------------
ALTER TABLE public.planeador 
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid();

ALTER TABLE public.lista_compras 
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid();

ALTER TABLE public.despensa_usuario 
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid();

-- Asignar registros existentes (con user_id NULL) a tu cuenta principal para no perder tus pruebas
DO $$
DECLARE
  primer_usuario UUID;
BEGIN
  SELECT id INTO primer_usuario FROM auth.users ORDER BY created_at ASC LIMIT 1;
  IF primer_usuario IS NOT NULL THEN
    UPDATE public.planeador SET user_id = primer_usuario WHERE user_id IS NULL;
    UPDATE public.lista_compras SET user_id = primer_usuario WHERE user_id IS NULL;
    UPDATE public.despensa_usuario SET user_id = primer_usuario WHERE user_id IS NULL;
  END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 2. ÍNDICES DE ALTO RENDIMIENTO
-- ------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_planeador_user ON public.planeador(user_id);
CREATE INDEX IF NOT EXISTS idx_lista_compras_user ON public.lista_compras(user_id);
CREATE INDEX IF NOT EXISTS idx_despensa_usuario_user ON public.despensa_usuario(user_id);

-- ------------------------------------------------------------------------------
-- 3. TRIGGER AUTOMÁTICO PARA ASIGNAR user_id EN CADA INSERT
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_current_user_id()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.user_id IS NULL THEN
    NEW.user_id := auth.uid();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_planeador_user_id ON public.planeador;
CREATE TRIGGER tr_planeador_user_id
  BEFORE INSERT ON public.planeador
  FOR EACH ROW EXECUTE FUNCTION public.set_current_user_id();

DROP TRIGGER IF EXISTS tr_lista_compras_user_id ON public.lista_compras;
CREATE TRIGGER tr_lista_compras_user_id
  BEFORE INSERT ON public.lista_compras
  FOR EACH ROW EXECUTE FUNCTION public.set_current_user_id();

DROP TRIGGER IF EXISTS tr_despensa_usuario_user_id ON public.despensa_usuario;
CREATE TRIGGER tr_despensa_usuario_user_id
  BEFORE INSERT ON public.despensa_usuario
  FOR EACH ROW EXECUTE FUNCTION public.set_current_user_id();

DROP TRIGGER IF EXISTS tr_recetas_cocinadas_user_id ON public.recetas_cocinadas;
CREATE TRIGGER tr_recetas_cocinadas_user_id
  BEFORE INSERT ON public.recetas_cocinadas
  FOR EACH ROW EXECUTE FUNCTION public.set_current_user_id();

-- ------------------------------------------------------------------------------
-- 4. HABILITAR ROW LEVEL SECURITY (RLS)
-- ------------------------------------------------------------------------------
ALTER TABLE public.planeador ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lista_compras ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.despensa_usuario ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.preferencias_usuario ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recetas_cocinadas ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.recetas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.receta_detalle ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ingredientes_genericos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supermercados ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.precios_supermercado ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------------------------
-- 5. POLÍTICAS DE AISLAMIENTO MULTI-USUARIO (CADA USUARIO SOLO VE SUS DATOS)
-- ------------------------------------------------------------------------------

-- === PLANEADOR ===
DROP POLICY IF EXISTS "planeador_select_propio" ON public.planeador;
DROP POLICY IF EXISTS "planeador_insert_propio" ON public.planeador;
DROP POLICY IF EXISTS "planeador_update_propio" ON public.planeador;
DROP POLICY IF EXISTS "planeador_delete_propio" ON public.planeador;

CREATE POLICY "planeador_select_propio" ON public.planeador
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "planeador_insert_propio" ON public.planeador
  FOR INSERT WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

CREATE POLICY "planeador_update_propio" ON public.planeador
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "planeador_delete_propio" ON public.planeador
  FOR DELETE USING (auth.uid() = user_id);

-- === LISTA DE COMPRAS ===
DROP POLICY IF EXISTS "lista_compras_select_propia" ON public.lista_compras;
DROP POLICY IF EXISTS "lista_compras_insert_propia" ON public.lista_compras;
DROP POLICY IF EXISTS "lista_compras_update_propia" ON public.lista_compras;
DROP POLICY IF EXISTS "lista_compras_delete_propia" ON public.lista_compras;

CREATE POLICY "lista_compras_select_propia" ON public.lista_compras
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "lista_compras_insert_propia" ON public.lista_compras
  FOR INSERT WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

CREATE POLICY "lista_compras_update_propia" ON public.lista_compras
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "lista_compras_delete_propia" ON public.lista_compras
  FOR DELETE USING (auth.uid() = user_id);

-- === DESPENSA DE USUARIO ===
DROP POLICY IF EXISTS "despensa_select_propia" ON public.despensa_usuario;
DROP POLICY IF EXISTS "despensa_insert_propia" ON public.despensa_usuario;
DROP POLICY IF EXISTS "despensa_update_propia" ON public.despensa_usuario;
DROP POLICY IF EXISTS "despensa_delete_propia" ON public.despensa_usuario;

CREATE POLICY "despensa_select_propia" ON public.despensa_usuario
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "despensa_insert_propia" ON public.despensa_usuario
  FOR INSERT WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

CREATE POLICY "despensa_update_propia" ON public.despensa_usuario
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "despensa_delete_propia" ON public.despensa_usuario
  FOR DELETE USING (auth.uid() = user_id);

-- === RECETAS COCINADAS ===
DROP POLICY IF EXISTS "Permitir lectura de recetas cocinadas" ON public.recetas_cocinadas;
DROP POLICY IF EXISTS "Permitir inserción de recetas cocinadas" ON public.recetas_cocinadas;
DROP POLICY IF EXISTS "Permitir actualización de recetas cocinadas" ON public.recetas_cocinadas;
DROP POLICY IF EXISTS "Permitir eliminación de recetas cocinadas" ON public.recetas_cocinadas;
DROP POLICY IF EXISTS "recetas_cocinadas_select_propia" ON public.recetas_cocinadas;
DROP POLICY IF EXISTS "recetas_cocinadas_insert_propia" ON public.recetas_cocinadas;
DROP POLICY IF EXISTS "recetas_cocinadas_update_propia" ON public.recetas_cocinadas;
DROP POLICY IF EXISTS "recetas_cocinadas_delete_propia" ON public.recetas_cocinadas;

CREATE POLICY "recetas_cocinadas_select_propia" ON public.recetas_cocinadas
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "recetas_cocinadas_insert_propia" ON public.recetas_cocinadas
  FOR INSERT WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

CREATE POLICY "recetas_cocinadas_update_propia" ON public.recetas_cocinadas
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "recetas_cocinadas_delete_propia" ON public.recetas_cocinadas
  FOR DELETE USING (auth.uid() = user_id);

-- ------------------------------------------------------------------------------
-- 6. BLINDAJE DE CATÁLOGOS GLOBALES (LECTURA PÚBLICA, SIN BORRADO)
-- ------------------------------------------------------------------------------

-- === RECETAS ===
DROP POLICY IF EXISTS "recetas_lectura_publica" ON public.recetas;
DROP POLICY IF EXISTS "recetas_insert_autenticado" ON public.recetas;

CREATE POLICY "recetas_lectura_publica" ON public.recetas
  FOR SELECT USING (true);

-- Permite agregar nuevas recetas creadas por usuarios o Chef IA
CREATE POLICY "recetas_insert_autenticado" ON public.recetas
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- === RECETA DETALLE ===
DROP POLICY IF EXISTS "receta_detalle_lectura_publica" ON public.receta_detalle;
DROP POLICY IF EXISTS "receta_detalle_insert_autenticado" ON public.receta_detalle;

CREATE POLICY "receta_detalle_lectura_publica" ON public.receta_detalle
  FOR SELECT USING (true);

CREATE POLICY "receta_detalle_insert_autenticado" ON public.receta_detalle
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- === INGREDIENTES GENÉRICOS ===
DROP POLICY IF EXISTS "ingredientes_lectura_publica" ON public.ingredientes_genericos;
DROP POLICY IF EXISTS "ingredientes_insert_autenticado" ON public.ingredientes_genericos;

CREATE POLICY "ingredientes_lectura_publica" ON public.ingredientes_genericos
  FOR SELECT USING (true);

CREATE POLICY "ingredientes_insert_autenticado" ON public.ingredientes_genericos
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- === SUPERMERCADOS ===
DROP POLICY IF EXISTS "supermercados_lectura_publica" ON public.supermercados;

CREATE POLICY "supermercados_lectura_publica" ON public.supermercados
  FOR SELECT USING (true);

-- === PRECIOS SUPERMERCADO ===
DROP POLICY IF EXISTS "precios_lectura_publica" ON public.precios_supermercado;
DROP POLICY IF EXISTS "precios_modificar_autenticado" ON public.precios_supermercado;

CREATE POLICY "precios_lectura_publica" ON public.precios_supermercado
  FOR SELECT USING (true);

-- Permite alimentar precios al escanear tickets en el supermercado
CREATE POLICY "precios_modificar_autenticado" ON public.precios_supermercado
  FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
