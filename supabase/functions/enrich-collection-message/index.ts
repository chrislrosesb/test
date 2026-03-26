import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

const ANTHROPIC_API_KEY = Deno.env.get('ANTHROPIC_API_KEY') ?? '';
const ALLOWED_ORIGIN   = 'https://chrislrose.aseva.ai';

interface Article {
  title:   string;
  domain:  string;
  note?:   string;
  summary?: string;
}

interface RequestBody {
  recipient?: string;
  message?:   string;   // raw hint from the user (optional)
  articles:   Article[];
}

serve(async (req) => {
  // CORS pre-flight
  const origin = req.headers.get('origin') ?? '';
  const corsHeaders: Record<string, string> = {
    'Access-Control-Allow-Origin':  origin === ALLOWED_ORIGIN || origin.endsWith('github.io') ? origin : ALLOWED_ORIGIN,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  };

  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405, headers: corsHeaders });
  }

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const { recipient, message, articles } = body;

  if (!articles || articles.length === 0) {
    return new Response(JSON.stringify({ error: 'No articles provided' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // Build article context for the prompt
  const articleContext = articles
    .map((a, i) => {
      const parts = [`${i + 1}. "${a.title}" (${a.domain})`];
      if (a.note)    parts.push(`   Chris's note: ${a.note}`);
      if (a.summary) parts.push(`   AI summary: ${a.summary}`);
      return parts.join('\n');
    })
    .join('\n\n');

  const recipientLine = recipient ? `The recipient's name is ${recipient}.` : 'The recipient is unnamed — address them warmly but without a name.';
  const hintLine      = message   ? `Chris's hint about why he's sharing: "${message}"` : 'Chris did not leave a specific reason — infer it from his notes and the articles.';

  const systemPrompt = `You write short, warm, human-sounding personal notes from Chris Rose to a friend.
Chris is thoughtful, enthusiastic about technology and ideas, and writes the way he talks.
Never sound like a marketing email. No em-dashes. No "I wanted to reach out." No bullet lists.
Write in first-person as Chris. Keep it under 120 words.`;

  const userPrompt = `Write a personal note from Chris to someone sharing a curated reading list.

${recipientLine}
${hintLine}

Articles Chris selected:
${articleContext}

Write 2–3 short paragraphs:
1. A warm greeting that mentions why he picked these specifically for this person (reference his notes or the article themes naturally).
2. One sentence teasing the most interesting article or idea to hook their attention.
3. A brief, friendly sign-off.

Do not use bullet points or numbered lists. Sound natural, not polished.`;

  try {
    const anthropicRes = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type':      'application/json',
        'x-api-key':         ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model:      'claude-haiku-4-5-20251001',
        max_tokens: 300,
        system:     systemPrompt,
        messages:   [{ role: 'user', content: userPrompt }],
      }),
    });

    if (!anthropicRes.ok) {
      const errText = await anthropicRes.text();
      console.error('Anthropic API error:', errText);
      return new Response(JSON.stringify({ error: 'AI service error' }), {
        status: 502,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const data = await anthropicRes.json();
    const enrichedMessage = data.content?.[0]?.text?.trim() ?? '';

    return new Response(JSON.stringify({ enrichedMessage }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (err) {
    console.error('Edge function error:', err);
    return new Response(JSON.stringify({ error: 'Internal error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
