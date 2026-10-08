import os
import json
import google.generativeai as genai
from supabase import create_client

# --- 1. TUS LLAVES MAESTRAS ---
SUPABASE_URL = "https://xjfzlthgycczcjbifaty.supabase.co"
SUPABASE_KEY = "sb_publishable_JKvX_4PX5it_s5nnYq8liQ_0e-L_dNd" # La misma que usaste en Flutter
GEMINI_KEY = os.environ["GEMINI_KEY"]  # Defínela una vez en Windows: setx GEMINI_KEY "tu_clave" (y reabre la terminal)

# --- 2. ENCENDEMOS LOS MOTORES ---
supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
genai.configure(api_key=GEMINI_KEY)
modelo = genai.GenerativeModel('gemini-3.6-flash')

# --- 3. LA RECETA DE PRUEBA ---
texto_receta = """
Para hacer unos deliciosos tacos de asada necesitamos:
- 500g de carne de res (arrachera)
- 1 cebolla blanca picada
- Un manojo de cilantro fresco
- Limones al gusto
- Sal y pimienta
"""

print("🧠 1. Pidiéndole a Gemini que lea la receta...")

# Le damos instrucciones estrictas a la IA para que devuelva el formato exacto de tu base de datos
instrucciones = f"""
Lee la siguiente receta y extrae los ingredientes. 
Devuelve ÚNICAMENTE un arreglo en formato JSON válido, sin texto adicional y sin formato markdown.
Cada ingrediente debe tener estas dos claves exactas:
- "nombre_estandar" (ejemplo: "Cilantro", "Carne de res")
- "categoria" (opciones: "Verduras", "Carnes", "Especias", "Frutas", "Otros")

Receta:
{texto_receta}
"""

respuesta_gemini = modelo.generate_content(instrucciones)

# Limpiamos la respuesta por si Gemini agregó símbolos de formato
texto_json = respuesta_gemini.text.strip().replace('```json', '').replace('```', '')

try:
    # Convertimos el texto inteligente a datos que Supabase entienda
    ingredientes_extraidos = json.loads(texto_json)
    print(f"✅ ¡Gemini encontró {len(ingredientes_extraidos)} ingredientes!")
    
    print("☁️ 2. Guardando en Supabase (ignorando duplicados)...")
    
    # MAGIA: El upsert guarda los nuevos y si alguno ya existe (como la cebolla), solo lo ignora o actualiza
    respuesta_db = supabase.table("ingredientes_genericos").upsert(
        ingredientes_extraidos, 
        on_conflict="nombre_estandar"
    ).execute()
    
    print("🎉 ¡Proceso terminado con éxito! Tu base de datos ha crecido en automático.")
    
except Exception as e:
    print(f"❌ Hubo un error: {e}")
    print("Lo que respondió Gemini fue:", texto_json)