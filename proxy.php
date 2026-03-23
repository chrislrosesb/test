<?php
/**
 * proxy.php — Image proxy for hotlink-protected CDN images
 *
 * Usage: /proxy.php?url=ENCODED_IMAGE_URL
 *
 * Fetches the image server-side (bypassing Referer-based hotlink protection)
 * and streams it back to the browser with caching headers.
 *
 * Allowed domains: Instagram/Threads CDN only (security whitelist).
 */

// ── Security: only proxy known CDN domains ─────────────────────────────────

$ALLOWED_HOSTS = [
    'cdninstagram.com',
    'fbcdn.net',
    'scontent.cdninstagram.com',
    'instagram.fxxxx',   // Instagram CDN subdomains
];

function isAllowed(string $url): bool {
    $host = parse_url($url, PHP_URL_HOST);
    if (!$host) return false;
    $allowed = ['cdninstagram.com', 'fbcdn.net'];
    foreach ($allowed as $d) {
        if ($host === $d || str_ends_with($host, '.' . $d)) return true;
    }
    return false;
}

// ── Input validation ────────────────────────────────────────────────────────

$url = isset($_GET['url']) ? trim($_GET['url']) : '';

if (!$url) { http_response_code(400); header('Content-Type: text/plain'); echo 'Missing url'; exit; }
if (!filter_var($url, FILTER_VALIDATE_URL)) { http_response_code(400); echo 'Invalid url'; exit; }
if (!isAllowed($url)) { http_response_code(403); echo 'Domain not allowed'; exit; }

// ── Fetch the image ─────────────────────────────────────────────────────────

$ctx = stream_context_create([
    'http' => [
        'method'          => 'GET',
        'header'          => implode("\r\n", [
            'User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
            'Referer: https://www.threads.net/',
            'Accept: image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
        ]),
        'timeout'         => 10,
        'follow_location' => true,
        'max_redirects'   => 3,
    ],
    'ssl' => [
        'verify_peer'      => true,
        'verify_peer_name' => true,
    ],
]);

$data = @file_get_contents($url, false, $ctx);

if ($data === false || strlen($data) === 0) {
    http_response_code(502);
    echo 'Failed to fetch image';
    exit;
}

// ── Determine content type from response headers ────────────────────────────

$contentType = 'image/jpeg';
if (!empty($http_response_header)) {
    foreach ($http_response_header as $h) {
        if (stripos($h, 'Content-Type:') === 0) {
            $contentType = trim(substr($h, 13));
            // Strip parameters like "; charset=utf-8"
            if (($semi = strpos($contentType, ';')) !== false) {
                $contentType = trim(substr($contentType, 0, $semi));
            }
            break;
        }
    }
}

// Only serve images
if (!str_starts_with($contentType, 'image/')) {
    http_response_code(415);
    echo 'Not an image';
    exit;
}

// ── Stream back to browser ──────────────────────────────────────────────────

header('Content-Type: ' . $contentType);
header('Cache-Control: public, max-age=86400');   // cache 24 h in browser
header('X-Content-Type-Options: nosniff');
header('Access-Control-Allow-Origin: *');

echo $data;
