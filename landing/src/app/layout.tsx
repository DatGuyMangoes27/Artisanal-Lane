import type { Metadata } from "next";
import { Inter, Playfair_Display } from "next/font/google";
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
      <body className={`${inter.variable} ${playfair.variable} font-sans antialiased relative`}>
        {/* Subtle noise texture overlay */}
        <div className="pointer-events-none fixed inset-0 z-[100] opacity-[0.03] mix-blend-overlay" style={{ backgroundImage: 'url("data:image/svg+xml,%3Csvg viewBox=%220 0 200 200%22 xmlns=%22http://www.w3.org/2000/svg%22%3E%3Cfilter id=%22noiseFilter%22%3E%3CfeTurbulence type=%22fractalNoise%22 baseFrequency=%220.65%22 numOctaves=%223%22 stitchTiles=%22stitch%22/%3E%3C/filter%3E%3Crect width=%22100%25%22 height=%22100%25%22 filter=%22url(%23noiseFilter)%22/%3E%3C/svg%3E")' }}></div>
        {children}
      </body>
    </html>
  );
}
