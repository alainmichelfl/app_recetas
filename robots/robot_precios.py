import os
import json
import time
from google import genai
from google.genai import types
from supabase import create_client

# --- 1. TUS LLAVES MAESTRAS ---
SUPABASE_URL = "https://xjfzlthgycczcjbifaty.supabase.co"
SUPABASE_KEY = "sb_publishable_JKvX_4PX5it_s5nnYq8liQ_0e-L_dNd"
GEMINI_KEY = os.environ["GEMINI_KEY"]  # Defínela una vez en Windows: setx GEMINI_KEY "tu_clave" (y reabre la terminal)

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
cliente_ia = genai.Client(api_key=GEMINI_KEY)

def actualizar_precios():
    print("🤖 Iniciando el Robot Cotizador Moderno...")
    
    # 1. Obtenemos los ingredientes
    print("📦 Leyendo ingredientes de tu base de datos...")
    respuesta_ingredientes = supabase.table("ingredientes_genericos").select("*").execute()
    ingredientes = respuesta_ingredientes.data
    
    if not ingredientes:
        print("❌ No hay ingredientes en la base de datos para cotizar.")
        return

    lista_nombres = ", ".join([ing['nombre_estandar'] for ing in ingredientes])
    print(f"✅ Encontré {len(ingredientes)} ingredientes: {lista_nombres}\n")

    # 2. Le pedimos a la IA que estime los precios
    print("🧠 Consultando los precios del mercado con Inteligencia Artificial...")
    instrucciones = f"""
    Actúa como un experto en supermercados de México. 
    A continuación, te daré una lista de ingredientes. Necesito que estimes un precio realista actual (en pesos mexicanos) para cada uno en 3 supermercados: Walmart (ID 1), Soriana (ID 2) y La Comer (ID 3).
    
    Ingredientes a cotizar:
    {json.dumps(ingredientes)}
    
    Devuelve ÚNICAMENTE un arreglo JSON con esta estructura exacta, generando un SKU inventado para cada uno:
    [
      {{
        "id_sku": "WAL-JIT-01",
        "id_super": 1,
        "id_ingrediente": ID_DEL_INGREDIENTE_AQUI,
        "nombre_comercial": "Jitomate Saladette 1kg",
        "precio": 35.50
      }}
    ]
    """

    # 3. Consultamos con paciencia (hasta 5 intentos)
    max_intentos = 5
    
    for intento in range(max_intentos):
        try:
            # Aquí usamos la nueva forma de comunicarnos con Gemini
            respuesta_gemini = cliente_ia.models.generate_content(
                model='gemini-3.8-flash',
                contents=instrucciones,
            )
            
            texto_json = respuesta_gemini.text.strip().replace('```json', '').replace('```', '')
            nuevos_precios = json.loads(texto_json)
            
            print(f"📊 La IA generó {len(nuevos_precios)} precios. Guardando en Supabase...")

            # Guardamos los precios
            for precio in nuevos_precios:
                supabase.table("catalogo_skus").upsert({
                    "id_sku": precio["id_sku"],
                    "id_super": precio["id_super"],
                    "id_ingrediente": precio["id_ingrediente"],
                    "nombre_comercial": precio["nombre_comercial"],
                    "precio": precio["precio"]
                }).execute()
                print(f"💰 Registrado: {precio['nombre_comercial']} a ${precio['precio']} en Supermercado {precio['id_super']}")

            print("\n🏆 ¡Catálogo de precios actualizado con éxito!")
            break # Si todo salió bien, rompemos el ciclo y terminamos
            
        except Exception as e:
            if '503' in str(e):
                print(f"⏳ Servidores ocupados (Intento {intento + 1} de {max_intentos}). Esperando 15 segundos para reintentar...")
                time.sleep(15) # Espera 15 segundos antes de volver a tocar la puerta
            else:
                print(f"❌ Hubo un error al procesar los precios: {e}")
                break # Si es un error distinto, nos detenemos

# Ejecutamos la función
actualizar_precios()