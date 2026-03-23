<?php
/**
 * c.php — Collection share link handler
 *
 * Two modes:
 *   ?id=abc123        → HTML page with dynamic OG tags, then JS-redirects to reading list
 *   ?id=abc123&img=1  → Returns dynamic SVG preview image
 */

$SUPABASE_URL = 'https://ownqyyfgferczpdgihgr.supabase.co';
$SUPABASE_KEY = 'sb_publishable_RPJSQlVO4isbKnZve8NlWg_55EO350Y';
$BASE_URL     = 'https://chrislrose.aseva.ai';

$id = isset($_GET['id']) ? preg_replace('/[^a-z0-9]/i', '', $_GET['id']) : '';
$img = isset($_GET['img']);

// ── Fetch collection from Supabase ────────────────────────────────────────────
function fetchCollection($id, $url, $key) {
    $endpoint = $url . '/rest/v1/collections?id=eq.' . urlencode($id) . '&select=*&limit=1';
    $ctx = stream_context_create(['http' => [
        'header' => "apikey: $key\r\nAuthorization: Bearer $key\r\n",
        'timeout' => 5,
    ]]);
    $raw = @file_get_contents($endpoint, false, $ctx);
    if (!$raw) return null;
    $rows = json_decode($raw, true);
    return (!empty($rows) && is_array($rows)) ? $rows[0] : null;
}

// ── Fallback values ───────────────────────────────────────────────────────────
$collection = $id ? fetchCollection($id, $SUPABASE_URL, $SUPABASE_KEY) : null;
$recipient  = $collection ? ($collection['recipient'] ?? '') : '';
$message    = $collection ? ($collection['message'] ?? '') : '';
$count      = $collection ? count($collection['link_ids'] ?? []) : 0;
$created    = $collection ? ($collection['created_at'] ?? '') : '';

$ogTitle = $recipient
    ? "Chris Rose curated $count article" . ($count !== 1 ? 's' : '') . " for $recipient"
    : "A curated reading list from Chris Rose";
$ogDesc = $message
    ? "$message — $count article" . ($count !== 1 ? 's' : '') . " picked just for you"
    : "$count article" . ($count !== 1 ? 's' : '') . " handpicked from Chris Rose's reading list";

$readingListUrl = $BASE_URL . '/reading-list.html' . ($id ? '?collection=' . urlencode($id) : '');
$imageUrl       = $BASE_URL . '/c.php?id=' . urlencode($id) . '&img=1';

// ── SVG image mode ────────────────────────────────────────────────────────────
if ($img) {
    header('Content-Type: image/svg+xml');
    header('Cache-Control: public, max-age=3600');

    // Truncate long strings for the image
    $displayRecipient = mb_strlen($recipient) > 22 ? mb_substr($recipient, 0, 22) . '…' : $recipient;
    $displayMessage   = mb_strlen($message) > 72 ? mb_substr($message, 0, 72) . '…' : $message;

    // Escape for SVG
    function svgEsc($s) { return htmlspecialchars($s, ENT_XML1 | ENT_QUOTES, 'UTF-8'); }

    $recipientLine = $displayRecipient
        ? 'For ' . svgEsc($displayRecipient)
        : 'A curated collection';
    $countLine     = $count . ' article' . ($count !== 1 ? 's' : '') . ' picked for you';
    $msgLine       = svgEsc($displayMessage);

    // Y positions — shift message block up if no personal message
    $countY   = $displayMessage ? 346 : 360;
    $msgShow  = $displayMessage ? '' : 'display:none';

    echo <<<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" viewBox="0 0 1200 630">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#0c0a1e"/>
      <stop offset="100%" stop-color="#1a1040"/>
    </linearGradient>
    <linearGradient id="shimmer" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#4f46e5"/>
      <stop offset="50%" stop-color="#7c3aed"/>
      <stop offset="100%" stop-color="#818cf8"/>
    </linearGradient>
    <linearGradient id="card" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#1e1b4b"/>
      <stop offset="100%" stop-color="#312e81"/>
    </linearGradient>
    <filter id="blur">
      <feGaussianBlur stdDeviation="40"/>
    </filter>
  </defs>

  <!-- Background -->
  <rect width="1200" height="630" fill="url(#bg)"/>

  <!-- Glow blobs -->
  <ellipse cx="200" cy="500" rx="300" ry="200" fill="#4f46e5" fill-opacity="0.12" filter="url(#blur)"/>
  <ellipse cx="1000" cy="150" rx="280" ry="200" fill="#7c3aed" fill-opacity="0.12" filter="url(#blur)"/>

  <!-- Subtle grid -->
  <g stroke="#ffffff" stroke-opacity="0.02" stroke-width="1">
    <line x1="0" y1="126" x2="1200" y2="126"/><line x1="0" y1="252" x2="1200" y2="252"/>
    <line x1="0" y1="378" x2="1200" y2="378"/><line x1="0" y1="504" x2="1200" y2="504"/>
    <line x1="200" y1="0" x2="200" y2="630"/><line x1="400" y1="0" x2="400" y2="630"/>
    <line x1="600" y1="0" x2="600" y2="630"/><line x1="800" y1="0" x2="800" y2="630"/>
    <line x1="1000" y1="0" x2="1000" y2="630"/>
  </g>

  <!-- Decorative stacked mini-cards top right -->
  <rect x="810" y="80" width="260" height="150" rx="14" fill="url(#card)" opacity="0.4" transform="rotate(-10 940 155)"/>
  <rect x="820" y="95" width="260" height="150" rx="14" fill="url(#card)" opacity="0.6" transform="rotate(-4 950 170)"/>
  <rect x="830" y="110" width="260" height="150" rx="14" fill="url(#card)" opacity="0.9"/>
  <rect x="852" y="132" width="140" height="8" rx="4" fill="#818cf8" fill-opacity="0.6"/>
  <rect x="852" y="150" width="200" height="6" rx="3" fill="#ffffff" fill-opacity="0.2"/>
  <rect x="852" y="164" width="170" height="6" rx="3" fill="#ffffff" fill-opacity="0.15"/>
  <rect x="852" y="210" width="52" height="18" rx="9" fill="#4f46e5" fill-opacity="0.6"/>
  <rect x="912" y="210" width="40" height="18" rx="9" fill="#7c3aed" fill-opacity="0.4"/>

  <!-- Sparkle stars decoration -->
  <text x="140" y="175" font-family="sans-serif" font-size="28" fill="#818cf8" fill-opacity="0.6">✦</text>
  <text x="1080" y="480" font-family="sans-serif" font-size="20" fill="#818cf8" fill-opacity="0.4">✦</text>
  <text x="1100" y="380" font-family="sans-serif" font-size="14" fill="#818cf8" fill-opacity="0.3">✦</text>

  <!-- "From" label -->
  <text x="116" y="190"
        font-family="-apple-system,BlinkMacSystemFont,'Helvetica Neue',sans-serif"
        font-size="17" font-weight="600" fill="#818cf8" letter-spacing="3" fill-opacity="0.8">FROM CHRIS ROSE</text>

  <!-- Accent bar -->
  <rect x="80" y="210" width="4" height="280" fill="url(#shimmer)" rx="2"/>

  <!-- Recipient ("For Sarah") -->
  <text x="116" y="310"
        font-family="-apple-system,BlinkMacSystemFont,'Helvetica Neue',sans-serif"
        font-size="68" font-weight="700" fill="#ffffff" letter-spacing="-2">{$recipientLine}</text>

  <!-- Count -->
  <text x="116" y="{$countY}"
        font-family="-apple-system,BlinkMacSystemFont,'Helvetica Neue',sans-serif"
        font-size="26" font-weight="400" fill="#818cf8">{$countLine}</text>

  <!-- Message (if present) -->
  <text x="116" y="393" style="{$msgShow}"
        font-family="-apple-system,BlinkMacSystemFont,'Helvetica Neue',sans-serif"
        font-size="21" font-weight="400" fill="#ffffff" fill-opacity="0.45">"{$msgLine}"</text>

  <!-- Divider -->
  <rect x="116" y="430" width="560" height="1" fill="#4f46e5" fill-opacity="0.4" rx="1"/>

  <!-- Domain -->
  <text x="116" y="462"
        font-family="-apple-system,BlinkMacSystemFont,'Helvetica Neue',sans-serif"
        font-size="18" font-weight="400" fill="#ffffff" fill-opacity="0.3">chrislrose.aseva.ai</text>

  <!-- Dot grid bottom right -->
  <g fill="#818cf8" fill-opacity="0.12">
    <circle cx="950" cy="570" r="3"/><circle cx="975" cy="570" r="3"/><circle cx="1000" cy="570" r="3"/>
    <circle cx="1025" cy="570" r="3"/><circle cx="1050" cy="570" r="3"/><circle cx="1075" cy="570" r="3"/>
    <circle cx="1100" cy="570" r="3"/><circle cx="950" cy="545" r="3"/><circle cx="975" cy="545" r="3"/>
    <circle cx="1000" cy="545" r="3"/><circle cx="1025" cy="545" r="3"/><circle cx="1050" cy="545" r="3"/>
    <circle cx="1075" cy="545" r="3"/><circle cx="1100" cy="545" r="3"/>
  </g>
</svg>
SVG;
    exit;
}

// ── HTML page mode ────────────────────────────────────────────────────────────
$ogTitleEsc = htmlspecialchars($ogTitle, ENT_QUOTES);
$ogDescEsc  = htmlspecialchars($ogDesc, ENT_QUOTES);
$imageUrlEsc = htmlspecialchars($imageUrl, ENT_QUOTES);
$readingListEsc = htmlspecialchars($readingListUrl, ENT_QUOTES);
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title><?= htmlspecialchars($ogTitle) ?></title>

  <!-- Open Graph -->
  <meta property="og:type"        content="website"/>
  <meta property="og:site_name"   content="Chris Rose"/>
  <meta property="og:url"         content="<?= htmlspecialchars($BASE_URL . '/c.php?id=' . urlencode($id)) ?>"/>
  <meta property="og:title"       content="<?= $ogTitleEsc ?>"/>
  <meta property="og:description" content="<?= $ogDescEsc ?>"/>
  <meta property="og:image"       content="<?= $imageUrlEsc ?>"/>
  <meta property="og:image:width"  content="1200"/>
  <meta property="og:image:height" content="630"/>
  <meta property="og:image:type"   content="image/svg+xml"/>

  <!-- Twitter / X Card -->
  <meta name="twitter:card"        content="summary_large_image"/>
  <meta name="twitter:title"       content="<?= $ogTitleEsc ?>"/>
  <meta name="twitter:description" content="<?= $ogDescEsc ?>"/>
  <meta name="twitter:image"       content="<?= $imageUrlEsc ?>"/>

  <!-- Apple iMessage / WhatsApp need these too -->
  <meta name="description" content="<?= $ogDescEsc ?>"/>

  <!-- Redirect users immediately; bots/scrapers don't follow JS -->
  <script>window.location.replace("<?= $readingListEsc ?>");</script>
  <noscript><meta http-equiv="refresh" content="0;url=<?= $readingListEsc ?>"/></noscript>

  <style>
    body { margin:0; background:#07070f; color:#fff;
           font-family:-apple-system,sans-serif; display:flex;
           align-items:center; justify-content:center; height:100vh; }
    p { color:#818cf8; font-size:18px; }
  </style>
</head>
<body>
  <p>Opening reading list…</p>
</body>
</html>
