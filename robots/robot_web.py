import os
import json
import requests
import time
from bs4 import BeautifulSoup
from google import genai # <-- NUEVA LIBRERÍA OFICIAL
from supabase import create_client

# --- 1. TUS LLAVES MAESTRAS ---
SUPABASE_URL = "https://xjfzlthgycczcjbifaty.supabase.co"
SUPABASE_KEY = "sb_publishable_JKvX_4PX5it_s5nnYq8liQ_0e-L_dNd"
GEMINI_KEY = os.environ["GEMINI_KEY"]  # Defínela una vez en Windows: setx GEMINI_KEY "tu_clave" (y reabre la terminal)

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

# NUEVA FORMA DE CONECTARSE A GEMINI
cliente_gemini = genai.Client(api_key=GEMINI_KEY)

# --- 2. LA LISTA DE TRABAJO DEL ROBOT ---
lista_recetas = [
    "https://www.kiwilimon.com/receta/platos-fuertes/mexicanos/tacos/tacos-al-pastor",
    "https://www.kiwilimon.com/receta/platos-fuertes/mexicanos/enchiladas/enchiladas-suizas-tradicionales",
    "https://www.kiwilimon.com/receta/platos-fuertes/mexicanos/pozole-rojo-de-cerdo-y-pollo",
    "https://www.kiwilimon.com/receta/guarniciones/guacamole-clasico"
]

print(f"🤖 ¡El robot ha despertado y va a procesar {len(lista_recetas)} recetas!\n")

# --- 3. EL CICLO AUTOMÁTICO ---
for url_receta in lista_recetas:
    print(f"🌐 Viajando a: {url_receta}...")
    
    try:
        headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}
        respuesta_web = requests.get(url_receta, headers=headers)
        sopa = BeautifulSoup(respuesta_web.text, 'html.parser')
        
        texto_pagina = sopa.get_text(separator=' ', strip=True)
        imagen_meta = sopa.find("meta", property="og:image")
        imagen_url = imagen_meta.get("content", "") if imagen_meta else ""
        
        print("🧠 Analizando con Inteligencia Artificial...")

        instrucciones = f"""
        Lee el siguiente texto extraído de una página de recetas. 
        Devuelve ÚNICAMENTE un objeto JSON válido con esta estructura exacta, sin texto adicional ni formato markdown:
        {{
          "titulo": "Nombre de la receta",
          "instrucciones": "1. Primer paso... 2. Segundo paso...",
          "porciones": 4,
          "tiempo_preparacion": "30 minutos",
          "dificultad": "Media",
          "categoria": "Platos Fuertes",
          "ingredientes": [
            {{
              "nombre_estandar": "Nombre del ingrediente",
              "categoria": "Verduras", 
              "cantidad": 1.5,
              "unidad_medida": "tazas"
            }}
          ]
        }}
        Texto de la página: {texto_pagina[:5000]}
        """

        # NUEVA FORMA DE PEDIRLE EL ANÁLISIS
        respuesta_gemini = cliente_gemini.models.generate_content(
            model='gemini-3.8-flash',
            contents=instrucciones,
        )
        
        texto_json = respuesta_gemini.text.strip().replace('```json', '').replace('```', '')
        datos = json.loads(texto_json)
        
        titulo = datos.get("titulo")
        if not titulo or titulo == 'None' or titulo == "":
            print("⚠️ La IA no pudo extraer el título correctamente. Saltando receta...")
            continue
            
        print(f"✅ ¡Encontrado! '{titulo}' ({datos.get('categoria', 'Sin categoría')}) para {datos.get('porciones', 2)} personas.")
        
        res_receta = supabase.table("recetas").insert({
            "titulo": titulo,
            "instrucciones": datos.get("instrucciones", "Pasos no disponibles"),
            "imagen_url": imagen_url,
            "porciones": datos.get("porciones", 2),
            "tiempo_preparacion": datos.get("tiempo_preparacion", "No especificado"),
            "dificultad": datos.get("dificultad", "Media"),
            "categoria": datos.get("categoria", "Plato Principal")
        }).execute()
        
        id_receta_nueva = res_receta.data[0]["id_receta"]
        
        for ing in datos.get("ingredientes", []):
            res_ing = supabase.table("ingredientes_genericos").upsert(
                {"nombre_estandar": ing["nombre_estandar"], "categoria": ing["categoria"]}, 
                on_conflict="nombre_estandar"
            ).execute()
            id_ingrediente_nuevo = res_ing.data[0]["id_ingrediente"]
            
            supabase.table("receta_detalle").insert({
                "id_receta": id_receta_nueva,
                "id_ingrediente": id_ingrediente_nuevo,
                "cantidad": ing.get("cantidad", 1),
                "unidad_medida": ing.get("unidad_medida", "pieza")
            }).execute()
            
        print(f"🎉 Receta guardada con éxito.")
        
    except Exception as e:
        print(f"❌ Hubo un error procesando esta receta: {e}")
    
    print("⏳ Tomando un respiro de 15 segundos para no bloquear la IA...")
    time.sleep(15)
    print(f"{'-'*50}\n")

print("🏆 ¡Misión de recolección terminada con éxito!")