import urllib.request
import json

url = 'https://xjfzlthgycczcjbifaty.supabase.co/rest/v1/'
key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhqZnpsdGhneWNjemNqYmlmYXR5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAxNzgwNjMsImV4cCI6MjEwNTc1NDA2M30.NUDw9b9woZaKow-JGn-bPBpaMI9aTpmrgCjiQzpTVg4'
headers = {'apikey': key, 'Authorization': f'Bearer {key}', 'Content-Type': 'application/json'}

def get(endpoint):
    req = urllib.request.Request(url + endpoint, headers=headers)
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode())

ings = {i['id_ingrediente']: i for i in get('ingredientes_genericos?select=*')}
precios = get('precios_supermercado?select=*')

print(f'Total ingredients in generic: {len(ings)}')
print(f'Total prices: {len(precios)}')

# Check Walmart prices sorted
w_items = [p for p in precios if p['id_supermercado'] == 1]
w_items.sort(key=lambda x: x['precio'], reverse=True)
print('\n=== TOP 20 WALMART EXPENSIVE ITEMS ===')
for p in w_items[:20]:
    ing = ings.get(p['id_ingrediente'], {})
    print(f"ID {p['id_ingrediente']:3d} | {ing.get('nombre_estandar', 'Unknown'):30s} | ${p['precio']:.2f} MXN ({ing.get('unidad_base', 'pza')})")

print('\n=== TOP 20 WALMART CHEAPEST ITEMS ===')
for p in w_items[-20:]:
    ing = ings.get(p['id_ingrediente'], {})
    print(f"ID {p['id_ingrediente']:3d} | {ing.get('nombre_estandar', 'Unknown'):30s} | ${p['precio']:.2f} MXN ({ing.get('unidad_base', 'pza')})")

print('\n=== Central de Abasto Anomaly Fixes Needed ===')
for p in precios:
    iid = p['id_ingrediente']
    ing = ings.get(iid, {})
    name = ing.get('nombre_estandar', 'Unknown')
    if p['id_supermercado'] == 4:
        # compare with Walmart
        w_p = next((x['precio'] for x in precios if x['id_ingrediente'] == iid and x['id_supermercado'] == 1), None)
        if w_p:
            if p['precio'] > w_p * 1.5 and p['precio'] > 20:
                print(f"EXCESSIVE in Abasto: {name} (ID {iid}): Abasto=${p['precio']}, Walmart=${w_p} (Abasto should be ~15-20% cheaper than Walmart)")
            elif p['precio'] < w_p * 0.35 and w_p > 20:
                print(f"UNDERPRICED in Abasto: {name} (ID {iid}): Abasto=${p['precio']}, Walmart=${w_p} (Abasto looks too low)")
