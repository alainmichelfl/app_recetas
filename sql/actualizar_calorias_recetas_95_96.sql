-- ==============================================================================
-- 🥗 ACTUALIZACIÓN DE CALORÍAS, MACROS E INSTRUCCIONES
-- Recetas:
-- 1. Bocaditos Energéticos de Avena, Cacahuate y Chocolate Negro (ID 96)
-- 2. Tazón Libre Especial de Quinoa y Vegetales (ID 95)
-- ==============================================================================

-- 1. Bocaditos Energéticos (ID 96)
UPDATE public.recetas
SET 
  calorias = 215,
  macros = 'Prot: 6g | Carbs: 24g | Grasas: 10g',
  tiempo_prep_minutos = 15,
  dificultad = 'Fácil',
  porciones = 4,
  porciones_base = 4,
  categoria = 'Snack',
  tipo_comida = 'Snack',
  instrucciones = '1. En un tazón mediano, integra la mantequilla de cacahuate natural, la miel de abeja y el extracto de vainilla. Si la mantequilla está firme, templa 10 segundos en el microondas.
2. Añade la avena en hojuelas, las semillas de chía y la pizca de sal marina. Revuelve vigorosamente hasta impregnar toda la avena.
3. Deja reposar la mezcla a temperatura ambiente un par de minutos e incorpora las chispas de chocolate negro.
4. Con las manos limpias y ligeramente húmedas, forma 12 esferas compactas y firmes (3 por porción).
5. Coloca en una bandeja con papel encerado y refrigera durante 20 minutos antes de servir.'
WHERE id_receta = 96;

-- 2. Tazón Libre de Quinoa y Vegetales (ID 95)
UPDATE public.recetas
SET 
  calorias = 350,
  macros = 'Prot: 22g | Carbs: 38g | Grasas: 12g',
  tiempo_prep_minutos = 15,
  dificultad = 'Fácil',
  porciones = 2,
  porciones_base = 2,
  categoria = 'Plato Principal',
  tipo_comida = 'Cena',
  instrucciones = '1. Enjuaga la quinoa y cuécela en agua a fuego medio durante 15 minutos hasta que esté tierna y esponjosa.
2. Pica los jitomates saladet y tus vegetales frescos en cubos medianos.
3. En una sartén con aceite de oliva extra virgen, saltea ligeramente los vegetales a fuego medio hasta que estén suaves.
4. En un tazón amplio, coloca la quinoa cocida como base, añade los vegetales salteados y sazona con un toque sutil de aceite de oliva y miel de agave orgánica.
5. ¡Sirve tibio y disfruta de este tazón balanceado y saciante!'
WHERE id_receta = 95;
