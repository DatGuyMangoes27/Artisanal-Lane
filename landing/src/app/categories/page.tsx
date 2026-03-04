import type { Metadata } from "next";
import Link from "next/link";
import Image from "next/image";
import { ArrowLeft, Palette, Shirt, Sparkles, Gem, Home, Baby } from "lucide-react";
import { Card, CardContent } from "@/components/ui/card";

export const metadata: Metadata = {
  title: "Categories — Artisan Lane",
  description: "Browse handcrafted goods across Art & Design, Clothing, Beauty, Jewellery, Home & Living, and Baby & Kids on Artisan Lane.",
};

const categories = [
  {
    name: "Art & Design",
    icon: Palette,
    description:
      "Original paintings, prints, illustrations, sculptures, and mixed-media artwork by South African artists. From contemporary canvas pieces to traditional African art forms.",
    examples: "Paintings, linocuts, ceramic sculptures, photography prints, handmade stationery, calligraphy",
  },
  {
    name: "Clothing",
    icon: Shirt,
    description:
      "Handcrafted and ethically made clothing, from everyday wear to statement pieces. African-print garments, hand-dyed textiles, and sustainably produced fashion.",
    examples: "African-print dresses, hand-dyed scarves, leather sandals, handwoven shawls, screen-printed tees",
  },
  {
    name: "Beauty",
    icon: Sparkles,
    description:
      "Natural, handmade beauty and skincare products crafted with indigenous South African ingredients. Soaps, balms, oils, and self-care essentials.",
    examples: "Shea butter creams, rooibos face masks, marula oil serums, handmade soaps, bath salts, lip balms",
  },
  {
    name: "Jewellery",
    icon: Gem,
    description:
      "One-of-a-kind handcrafted jewellery, from traditional Zulu beadwork to contemporary metalwork. Each piece carries the maker's signature style.",
    examples: "Beaded necklaces, brass earrings, wire-wrapped rings, anklets, statement cuffs, semi-precious stone pendants",
  },
  {
    name: "Home & Living",
    icon: Home,
    description:
      "Handmade homeware and décor to bring warmth and character to your space. Ceramics, woven baskets, candles, and artisan-made preserves and sauces.",
    examples: "Ceramic vases, woven baskets, soy candles, wooden boards, macramé wall hangings, chutney, preserves",
  },
  {
    name: "Baby & Kids",
    icon: Baby,
    description:
      "Thoughtfully handmade items for little ones — safe, beautiful, and made with care. Toys, clothing, nursery décor, and keepsakes.",
    examples: "Crochet toys, wooden rattles, handmade baby blankets, nursery prints, personalised name signs",
  },
];

export default function CategoriesPage() {
  return (
    <main className="min-h-screen">
      <nav className="glass sticky top-0 z-50 shadow-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <Link href="/" className="flex items-center gap-2">
              <Image src="/logo.png" alt="Artisan Lane" width={36} height={36} className="rounded-lg" />
              <span className="text-xl font-bold text-[#3A1F10]">Artisan Lane</span>
            </Link>
            <Link href="/" className="text-sm font-medium text-muted-foreground hover:text-foreground transition-colors flex items-center gap-1">
              <ArrowLeft className="w-4 h-4" /> Back
            </Link>
          </div>
        </div>
      </nav>

      <section className="py-20">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <h1 className="text-4xl md:text-5xl font-bold mb-4 text-[#3A1F10]">
            Browse by Category
          </h1>
          <p className="text-lg text-muted-foreground mb-12 max-w-2xl">
            Every item on Artisan Lane is handcrafted by a verified South African artisan.
            Explore our categories to find something truly unique.
          </p>

          <div className="space-y-6">
            {categories.map((cat) => (
              <Card key={cat.name} className="group hover:shadow-lg hover:shadow-[#7A0000]/5 transition-all duration-300">
                <CardContent className="p-6 sm:p-8">
                  <div className="flex items-start gap-5">
                    <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-[#7A0000]/10 to-[#D4A020]/10 flex items-center justify-center shrink-0 group-hover:from-[#7A0000]/20 group-hover:to-[#D4A020]/20 transition-colors">
                      <cat.icon className="w-7 h-7 text-[#7A0000]" />
                    </div>
                    <div>
                      <h2 className="text-xl font-semibold mb-2 text-[#3A1F10]">{cat.name}</h2>
                      <p className="text-muted-foreground mb-3">{cat.description}</p>
                      <p className="text-sm text-[#7A0000]/70">
                        <span className="font-medium text-[#7A0000]">Examples:</span> {cat.examples}
                      </p>
                    </div>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>

          <div className="mt-16 text-center p-8 bg-[#F7E4CC]/30 rounded-2xl border border-[#EDD5BE]">
            <h3 className="text-xl font-semibold mb-2 text-[#3A1F10]">More Categories Coming Soon</h3>
            <p className="text-muted-foreground max-w-md mx-auto">
              As our community of artisans grows, so will our categories. Have a suggestion?
              Let us know at{" "}
              <a href="mailto:hello@artisanlane.co.za" className="text-[#7A0000] hover:underline">
                hello@artisanlane.co.za
              </a>
            </p>
          </div>
        </div>
      </section>
    </main>
  );
}
