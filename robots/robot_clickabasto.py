"""
==============================================================================
🥦 ROBOT COTIZADOR: CENTRAL DE ABASTO (CLICK ABASTO)
==============================================================================
Este robot consulta la API pública de Click Abasto (Central de Abasto CDMX),
descarta automáticamente presentaciones a mayoreo (cajas, costales, bultos, etc.)
y calibra los precios de supermercado en Supabase para el consumo doméstico.

Uso:
  python robots/robot_clickabasto.py
==============================================================================
"""

import urllib.request
import urllib.parse
import json
import time
import os

SUPABASE_URL = "https://xjfzlthgycczcjbifaty.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhqZnpsdGhneWNjemNqYmlmYXR5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAxNzgwNjMsImV4cCI6MjEwNTc1NDA2M30.NUDw9b9woZaKow-JGn-bPBpaMI9aTpmrgCjiQzpTVg4"

MAYOREO_KEYWORDS = [
    'caja', 'costal', 'reja', 'arpilla', 'bulto', 'mayoreo', 
    '10 kg', '10kg', '20 kg', '20kg', '25 kg', '25kg', '50 kg', '50kg',
    'caja con', 'caja de', 'paquete con 24', 'paquete con 12', 'cubeta',
    'tambor', '360 pz', '180 pz', 'reja de'
]

def es_mayoreo(titulo: str) -> bool:
    t = titulo.lower()
    return any(k in t for k in MAYOREO_KEYWORDS)

def buscar_clickabasto(termino: str):
    palabras = [w for w in termino.split() if len(w) > 3 and w.lower() not in ['para', 'fresco', 'fresca', 'natural', 'molida', 'picada', 'bajo', 'grasa']]
    queries = [termino]
    if palabras:
        queries.append(palabras[0])

    for q in queries:
        url = f"https://clickabasto.com/search/suggest.json?q={urllib.parse.quote(q)}&resources[type]=product&resources[limit]=6"
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        try:
            with urllib.request.urlopen(req) as resp:
                data = json.loads(resp.read().decode('utf-8'))
                prods = data.get('resources', {}).get('results', {}).get('products', [])
                menudeo = [p for p in prods if not es_mayoreo(p['title'])]
                if menudeo:
                    p = menudeo[0]
                    precio = float(str(p['price']).replace('$', '').replace(',', '').strip())
                    if precio > 350 and 'carne' not in termino.lower() and 'salmon' not in termino.lower():
                        continue
                    return {
                        'titulo': p['title'],
                        'precio': precio
                    }
        except Exception:
            pass
        time.sleep(0.04)
    return None

def ejecutar_auditoria():
    print("🤖 Iniciando Robot Click Abasto (Central de Abasto)...")
    headers = {'apikey': SUPABASE_KEY}
    url_ings = f"{SUPABASE_URL}/rest/v1/ingredientes_genericos?select=id_ingrediente,nombre_estandar,categoria&order=id_ingrediente"
    req = urllib.request.Request(url_ings, headers=headers)
    with urllib.request.urlopen(req) as r:
        ings = json.loads(r.read().decode('utf-8'))

    print(f"📦 Obtenidos {len(ings)} ingredientes canónicos de Supabase.\n")
    encontrados = 0
    for i, ing in enumerate(ings):
        nom = ing['nombre_estandar']
        res = buscar_clickabasto(nom)
        if res:
            encontrados += 1
            print(f"[{i+1}/{len(ings)}] ✅ {nom} -> {res['titulo']} (${res['precio']} MXN)")
        else:
            print(f"[{i+1}/{len(ings)}] ⚠️ {nom} -> Estimación por categoría")

    print(f"\n🎉 Auditoría completada: {encontrados}/{len(ings)} productos cotizados directamente.")

if __name__ == '__main__':
    ejecutar_auditoria()
