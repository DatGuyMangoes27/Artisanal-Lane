import type { Metadata } from "next";
import { Inter, Playfair_Display } from "next/font/google";
import Script from "next/script";
import "./globals.css";

const inter = Inter({
  variable: "--font-inter",
  subsets: ["latin"],
});

const playfair = Playfair_Display({
  variable: "--font-playfair",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Artisan Lane — Curated Craft Marketplace",
  description: "Discover unique handmade goods from South Africa's finest artisans. Artisan Lane is a curated marketplace where every product tells a story of craftsmanship.",
  keywords: ["handmade", "artisan", "craft marketplace", "South Africa", "handcrafted goods", "curated marketplace", "artisanal products"],
  authors: [{ name: "Artisan Lane" }],
  icons: {
    icon: "/logo.png",
    apple: "/logo.png",
  },
  openGraph: {
    title: "Artisan Lane — Curated Craft Marketplace",
    description: "Discover unique handmade goods from South Africa's finest artisans.",
    type: "website",
    locale: "en_ZA",
    images: ["/logo.png"],
  },
  twitter: {
    card: "summary_large_image",
    title: "Artisan Lane — Curated Craft Marketplace",
    description: "Discover unique handmade goods from South Africa's finest artisans.",
    images: ["/logo.png"],
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="scroll-smooth">
      <head>
        <meta
          name="facebook-domain-verification"
          content="vzpvpu5gikpmkqa7esir1tyo4lvzpe"
        />
      </head>
      <body className={`${inter.variable} ${playfair.variable} font-sans antialiased relative`}>
        <Script id="meta-pixel" strategy="afterInteractive">
          {`!function(f,b,e,v,n,t,s)
{if(f.fbq)return;n=f.fbq=function(){n.callMethod?
n.callMethod.apply(n,arguments):n.queue.push(arguments)};
if(!f._fbq)f._fbq=n;n.push=n;n.loaded=!0;n.version='2.0';
n.queue=[];t=b.createElement(e);t.async=!0;
t.src=v;s=b.getElementsByTagName(e)[0];
s.parentNode.insertBefore(t,s)}(window, document,'script',
'https://connect.facebook.net/en_US/fbevents.js');
fbq('init', '2004374160517759');
fbq('track', 'PageView');`}
        </Script>
        <noscript>
          <img
            height="1"
            width="1"
            style={{ display: "none" }}
            src="https://www.facebook.com/tr?id=2004374160517759&ev=PageView&noscript=1"
            alt=""
          />
        </noscript>
        {/* Subtle noise texture overlay */}
        <div className="pointer-events-none fixed inset-0 z-[100] opacity-[0.03] mix-blend-overlay" style={{ backgroundImage: 'url("data:image/svg+xml,%3Csvg viewBox=%220 0 200 200%22 xmlns=%22http://www.w3.org/2000/svg%22%3E%3Cfilter id=%22noiseFilter%22%3E%3CfeTurbulence type=%22fractalNoise%22 baseFrequency=%220.65%22 numOctaves=%223%22 stitchTiles=%22stitch%22/%3E%3C/filter%3E%3Crect width=%22100%25%22 height=%22100%25%22 filter=%22url(%23noiseFilter)%22/%3E%3C/svg%3E")' }}></div>
        {children}
      </body>
    </html>
  );
}
