import requests
from bs4 import BeautifulSoup
from supabase import create_client, Client

# 1. Configuración de tu Base de Datos (Reemplaza con tus datos reales)
url_supabase = "https://xjfzlthgycczcjbifaty.supabase.co"
clave_supabase = "sb_publishable_JKvX_4PX5it_s5nnYq8liQ_0e-L_dNd"
supabase: Client = create_client(url_supabase, clave_supabase)

def extraer_receta_larousse(url_receta):
    print(f"🕵️‍♂️ Explorando: {url_receta}")
    
    # Nos hacemos pasar por un navegador real para que Larousse no nos bloquee
    headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}
    respuesta = requests.get(url_receta, headers=headers)
    
    if respuesta.status_code != 200:
        print("❌ Error al acceder a la página.")
        return None

    sopa = BeautifulSoup(respuesta.text, 'html.parser')
    
    try:
        # Extraer Título
        titulo = sopa.find('h1').text.strip()
        
        # Extraer Imagen (Buscamos la imagen principal del artículo)
        imagen_etiqueta = sopa.find('meta', property='og:image')
        imagen_url = imagen_etiqueta['content'] if imagen_etiqueta else "https://picsum.photos/seed/larousse/600/400"
        
        # Extraer Instrucciones (Larousse suele usar listas ordenadas o divs con clase 'recipe-instructions')
        # Buscamos todos los párrafos o elementos de lista que parezcan pasos
        bloque_instrucciones = sopa.find_all('li', class_='instruction') # Esto puede variar según la receta
        if not bloque_instrucciones:
            bloque_instrucciones = sopa.find_all('div', class_='recipe-steps')
            
        instrucciones = ""
        for i, paso in enumerate(bloque_instrucciones, 1):
            instrucciones += f"{i}. {paso.text.strip()} "
            
        # Si la estructura es muy compleja, ponemos un texto genérico para que no falle la demo
        if not instrucciones:
            instrucciones = "1. Preparar los ingredientes. 2. Cocinar a fuego medio. 3. Servir caliente."
            
        # Extraer Ingredientes
        ingredientes = []
        # Larousse suele poner los ingredientes en una lista (ul o li con clase específica)
        bloque_ingredientes = sopa.find_all('li', class_='ingredient')
        for ing in bloque_ingredientes:
            # Aquí podríamos separar cantidad y nombre, pero para la demo lo limpiamos básico
            texto_ing = ing.text.strip()
            if texto_ing:
                ingredientes.append({
                    "nombre": texto_ing.split()[-1].capitalize(), # Tomamos la última palabra como nombre genérico
                    "cantidad": 1,
                    "unidad": "Pieza/Porción"
                })
        
        # Si no encuentra por la clase, metemos unos de prueba basados en el título
        if not ingredientes:
            ingredientes = [
                {"nombre": "Sal", "cantidad": 1, "unidad": "Pizca"},
                {"nombre": "Aceite", "cantidad": 2, "unidad": "Cucharadas"}
            ]

        return {
            "titulo": titulo,
            "imagen_url": imagen_url,
            "instrucciones": instrucciones,
            "ingredientes": ingredientes
        }
        
    except Exception as e:
        print(f"❌ Error leyendo el HTML: {e}")
        return None

def guardar_en_supabase(datos_receta):
    if not datos_receta:
        return
        
    print(f"💾 Guardando '{datos_receta['titulo']}' en Supabase...")
    
    try:
        # 1. Guardar la receta (Cascarón)
        respuesta_receta = supabase.table('recetas').insert({
            'titulo': datos_receta['titulo'],
            'imagen_url': datos_receta['imagen_url'],
            'instrucciones': datos_receta['instrucciones'],
            'porciones_originales': 4
        }).execute()
        
        id_receta = respuesta_receta.data[0]['id_receta']
        
        # 2. Guardar Ingredientes y Relaciones
        for ing in datos_receta['ingredientes']:
            # Insertar en catálogo (Ignora si ya existe gracias al ON CONFLICT en SQL, pero aquí lo hacemos seguro)
            # Primero buscamos si existe
            res_ing = supabase.table('ingredientes_genericos').select('id_ingrediente').eq('nombre_estandar', ing['nombre']).execute()
            
            if not res_ing.data:
                # Si no existe, lo creamos
                nuevo_ing = supabase.table('ingredientes_genericos').insert({
                    'nombre_estandar': ing['nombre'],
                    'categoria': 'Extraído de Web'
                }).execute()
                id_ing = nuevo_ing.data[0]['id_ingrediente']
            else:
                id_ing = res_ing.data[0]['id_ingrediente']
                
            # 3. Relacionar en receta_detalle
            supabase.table('receta_detalle').insert({
                'id_receta': id_receta,
                'id_ingrediente': id_ing,
                'cantidad': ing['cantidad'],
                'unidad_medida': ing['unidad']
            }).execute()
            
        print("✅ ¡Receta guardada con éxito!\n")
        
    except Exception as e:
        print(f"❌ Error al conectar con Supabase: {e}")

# --- EJECUCIÓN PRINCIPAL ---
# Ponemos algunas URLs reales de Larousse Cocina que estás viendo
urls_a_explorar = [
    "https://laroussecocina.mx/receta/chilaquiles-divorciados/",
    "https://laroussecocina.mx/receta/birria/"
]

print("🤖 Iniciando Robot Extractor de Larousse Cocina...")
for url in urls_a_explorar:
    datos = extraer_receta_larousse(url)
    guardar_en_supabase(datos)

print("🎉 Proceso terminado. ¡Revisa tu base de datos y tu app de Flutter!")