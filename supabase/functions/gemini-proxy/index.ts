// 🛡️ Supabase Edge Function: gemini-proxy
// Blindaje R1: Oculta la clave GEMINI_API_KEY en el servidor, aplica CORS y limita cuotas (Rate-Limiting).
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Rate-limiting en memoria por IP/Token (máximo 30 peticiones por ventana de 5 minutos por cliente)
const rateLimitMap = new Map<string, { count: number; resetTime: number }>();
const MAX_REQUESTS_PER_WINDOW = 30;
const WINDOW_MS = 5 * 60 * 1000; // 5 minutos

function checkRateLimit(clientId: string): { allowed: boolean; remaining: number } {
  const now = Date.now();
  const clientRecord = rateLimitMap.get(clientId);

  if (!clientRecord || now > clientRecord.resetTime) {
    rateLimitMap.set(clientId, { count: 1, resetTime: now + WINDOW_MS });
    return { allowed: true, remaining: MAX_REQUESTS_PER_WINDOW - 1 };
  }

  if (clientRecord.count >= MAX_REQUESTS_PER_WINDOW) {
    return { allowed: false, remaining: 0 };
  }

  clientRecord.count++;
  return { allowed: true, remaining: MAX_REQUESTS_PER_WINDOW - clientRecord.count };
}

serve(async (req) => {
  // 1. Manejo de pre-flight CORS para navegadores y PWA
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Método no permitido. Use POST." }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    // 2. Control de Rate-Limiting por IP o Header de Autorización
    const clientIdentifier =
      req.headers.get("x-forwarded-for") ||
      req.headers.get("authorization") ||
      "cliente-anonimo";

    const { allowed, remaining } = checkRateLimit(clientIdentifier);
    if (!allowed) {
      return new Response(
        JSON.stringify({
          error: "Has superado el límite de seguridad de 30 consultas por cada 5 minutos.",
        }),
        {
          status: 429,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
            "X-RateLimit-Remaining": "0",
            "Retry-After": "300",
          },
        }
      );
    }

    // 3. Obtención segura de la API Key desde Supabase Secrets
    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) {
      return new Response(
        JSON.stringify({
          error: "Falta configurar el secreto GEMINI_API_KEY en Supabase Dashboard (Settings -> Secrets).",
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 4. Procesamiento del Payload de la petición
    const body = await req.json();
    if (!body || !body.contents) {
      return new Response(
        JSON.stringify({ error: "Payload inválido: debe contener el campo 'contents'." }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 5. Llamada segura en servidor a Google Gemini (Modelo gemini-2.5-flash)
    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`;
    const respuestaGemini = await fetch(geminiUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });

    if (!respuestaGemini.ok) {
      const errorText = await respuestaGemini.text();
      return new Response(
        JSON.stringify({
          error: `Error de Google Gemini (${respuestaGemini.status})`,
          detalle: errorText,
        }),
        {
          status: respuestaGemini.status,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const jsonGemini = await respuestaGemini.json();
    const candidate = jsonGemini.candidates?.[0];
    const textoExtraido = candidate?.content?.parts?.[0]?.text ?? "";

    // 6. Respuesta limpia hacia la app Flutter
    return new Response(
      JSON.stringify({
        texto: textoExtraido,
        candidate: candidate,
      }),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
          "X-RateLimit-Remaining": remaining.toString(),
        },
      }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({
        error: "Error interno al procesar en Supabase Edge Function",
        detalle: (error as Error).message,
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
