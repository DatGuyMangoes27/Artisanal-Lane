// @ts-nocheck
const META_HTML = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="facebook-domain-verification" content="vzpvpu5gikpmkqa7esir1tyo4lvzpe" />
  <meta property="og:title" content="Artisan Lane — Curated Craft Marketplace" />
  <meta property="og:description" content="Discover unique handmade goods from South Africa's finest artisans. Artisan Lane is a curated marketplace where every product tells a story of craftsmanship." />
  <meta property="og:url" content="https://artisanlanesa.co.za/" />
  <meta property="og:type" content="website" />
  <meta property="og:image" content="https://artisanlanesa.co.za/logo.png" />
  <meta property="og:locale" content="en_ZA" />
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content="Artisan Lane — Curated Craft Marketplace" />
  <meta name="twitter:description" content="Discover unique handmade goods from South Africa's finest artisans." />
  <meta name="twitter:image" content="https://artisanlanesa.co.za/logo.png" />
  <title>Artisan Lane — Curated Craft Marketplace</title>
  <meta name="description" content="Discover unique handmade goods from South Africa's finest artisans. Artisan Lane is a curated marketplace where every product tells a story of craftsmanship." />
</head>
<body>
  <h1>Artisan Lane — Curated Craft Marketplace</h1>
  <p>Discover unique handmade goods from South Africa's finest artisans.</p>
  <noscript>
    <img height="1" width="1" style="display:none" src="https://www.facebook.com/tr?id=2004374160517759&ev=PageView&noscript=1" alt="" />
  </noscript>
</body>
</html>`;

export default async (request, context) => {
  const ua = request.headers.get("user-agent") || "";

  const isFacebookCrawler =
    ua.includes("facebookexternalhit") || ua.includes("Facebot");

  if (!isFacebookCrawler) {
    return;
  }

  return new Response(META_HTML, {
    status: 200,
    headers: {
      "content-type": "text/html; charset=utf-8",
      "cache-control": "public, max-age=3600",
    },
  });
};

export const config = {
  path: "/*",
};
