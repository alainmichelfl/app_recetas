-- ==============================================================================
-- TABLA: recetas_cocinadas
-- Descripción: Registra el historial de recetas que el usuario ha cocinado,
-- ya sea desde la pantalla de detalle, desde el Modo Cocina guiado,
-- o directamente desde el Planeador Semanal.
-- ==============================================================================

CREATE TABLE IF NOT EXISTS recetas_cocinadas (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    id_receta BIGINT REFERENCES recetas(id_receta) ON DELETE SET NULL,
    titulo TEXT NOT NULL,
    fecha_cocinada TIMESTAMPTZ DEFAULT NOW(),
    origen TEXT DEFAULT 'detalle', -- 'detalle', 'modo_cocina', 'planeador'
    id_planeador BIGINT,
    creado_en TIMESTAMPTZ DEFAULT NOW()
);

-- Índices recomendados para búsquedas rápidas por usuario y receta
CREATE INDEX IF NOT EXISTS idx_recetas_cocinadas_receta ON recetas_cocinadas(id_receta);
CREATE INDEX IF NOT EXISTS idx_recetas_cocinadas_user ON recetas_cocinadas(user_id);
CREATE INDEX IF NOT EXISTS idx_recetas_cocinadas_fecha ON recetas_cocinadas(fecha_cocinada DESC);

-- Habilitar Row Level Security (RLS)
ALTER TABLE recetas_cocinadas ENABLE ROW LEVEL SECURITY;

-- Políticas de RLS que permiten lectura y escritura libre o autenticada
CREATE POLICY "Permitir lectura de recetas cocinadas"
ON recetas_cocinadas FOR SELECT
USING (true);

CREATE POLICY "Permitir inserción de recetas cocinadas"
ON recetas_cocinadas FOR INSERT
WITH CHECK (true);

CREATE POLICY "Permitir actualización de recetas cocinadas"
ON recetas_cocinadas FOR UPDATE
USING (true);

CREATE POLICY "Permitir eliminación de recetas cocinadas"
ON recetas_cocinadas FOR DELETE
USING (true);
