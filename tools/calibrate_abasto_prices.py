import urllib.request
import json

url = 'https://xjfzlthgycczcjbifaty.supabase.co/rest/v1/'
key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhqZnpsdGhneWNjemNqYmlmYXR5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAxNzgwNjMsImV4cCI6MjEwNTc1NDA2M30.NUDw9b9woZaKow-JGn-bPBpaMI9aTpmrgCjiQzpTVg4'
headers = {
    'apikey': key,
    'Authorization': f'Bearer {key}',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation'
}

# Calibration mapping for Central de Abasto (id_supermercado = 4)
# Adjusting wholesale bulk kilo prices to retail consumer portions matching other supermarkets,
# maintaining the realistic ~15-20% discount of Central de Abasto.
fixes = {
    47: 13.50,   # Orégano (bolsita/frasco)
    50: 14.00,   # Canela (sobre/atado 50g-100g)
    63: 34.00,   # Yogurt griego natural (bote 900g-1kg)
    65: 46.00,   # Nueces (bolsa 100g)
    76: 38.00,   # Quinoa (bolsa 250-500g)
    77: 12.50,   # Semillas de ajonjolí (bolsa 100g)
    96: 12.00,   # Pasta de achiote (caja 100g)
    99: 46.00,   # Nuez picada (bolsa 100g)
    108: 46.00,  # Almendras (bolsa 100g)
    112: 25.00,  # Semillas de chía (bolsa 250g)
    119: 14.00,  # Páprika en polvo (frasco/bolsa 100g)
    130: 46.00,  # Nuez pecana (bolsa 100g)
    137: 33.50,  # Cacao en polvo sin azúcar (bolsa 150g)
    146: 46.00,  # Almendras fileteadas (bolsa 100g)
    155: 34.00,  # Yogurt griego sin azúcar (bote 900g-1kg)
    164: 14.00,  # Orégano seco (bolsa/frasco)
    168: 25.00,  # Semillas de calabaza (pepitas 100g)
}

print(f"Applying {len(fixes)} price calibrations to Central de Abasto...")

for id_ing, new_price in fixes.items():
    endpoint = f"precios_supermercado?id_ingrediente=eq.{id_ing}&id_supermercado=eq.4"
    data = json.dumps({'precio': new_price}).encode('utf-8')
    req = urllib.request.Request(url + endpoint, data=data, headers=headers, method='PATCH')
    try:
        with urllib.request.urlopen(req) as resp:
            res = json.loads(resp.read().decode())
            print(f"Updated ing {id_ing} -> ${new_price} MXN: {res}")
    except Exception as e:
        print(f"Error updating ing {id_ing}: {e}")

print("All calibrations applied!")
