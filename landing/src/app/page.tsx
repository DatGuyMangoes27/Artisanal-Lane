"use client";

import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";
import {
  Search,
  ShoppingBag,
  Store,
  Shield,
  Truck,
  Heart,
  Star,
  Check,
  Apple,
  Palette,
  Sparkles,
  Users,
  ArrowRight,
  Gem,
  MapPin,
  ClipboardList,
  Package,
  Flag,
} from "lucide-react";
import Link from "next/link";
import Image from "next/image";
import { useState, useEffect } from "react";

function PhoneFrame({
  src,
  alt,
  className = "",
  priority = false,
}: {
  src: string;
  alt: string;
  className?: string;
  priority?: boolean;
}) {
  return (
    <div className={`relative ${className}`}>
      <div className="relative w-[280px] h-[580px] bg-gradient-to-b from-zinc-800 to-zinc-900 rounded-[2.5rem] p-[6px] shadow-2xl">
        <div className="absolute inset-0 rounded-[2.5rem] bg-gradient-to-br from-white/20 via-transparent to-black/20 pointer-events-none" />
        <div className="relative w-full h-full bg-black rounded-[2.2rem] overflow-hidden">
          <Image
            src={src}
            alt={alt}
            fill
            sizes="280px"
            className="object-cover object-top"
            priority={priority}
          />
        </div>
      </div>
    </div>
  );
}

function SmallPhoneFrame({
  src,
  alt,
  className = "",
}: {
  src: string;
  alt: string;
  className?: string;
}) {
  return (
    <div className={`relative ${className}`}>
      <div className="relative w-[200px] h-[420px] bg-gradient-to-b from-zinc-800 to-zinc-900 rounded-[1.75rem] p-[5px] shadow-xl">
        <div className="absolute inset-0 rounded-[1.75rem] bg-gradient-to-br from-white/10 via-transparent to-black/20 pointer-events-none" />
        <div className="relative w-full h-full bg-black rounded-[1.5rem] overflow-hidden">
          <Image
            src={src}
            alt={alt}
            fill
            sizes="200px"
            className="object-cover object-top"
          />
        </div>
      </div>
    </div>
  );
}

function Navigation() {
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const handleScroll = () => {
      setScrolled(window.scrollY > 50);
    };
    window.addEventListener("scroll", handleScroll);
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  return (
    <nav
      className={`fixed top-0 left-0 right-0 z-50 transition-all duration-300 ${
        scrolled ? "glass shadow-lg" : "bg-transparent"
      }`}
    >
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          <Link href="/" className="flex items-center gap-2">
            <Image
              src="/logo.png"
              alt="Artisan Lane Logo"
              width={36}
              height={36}
              className="rounded-lg"
            />
            <span className="text-xl font-bold text-[#3A1F10]">Artisan Lane</span>
          </Link>

          <div className="hidden md:flex items-center gap-8">
            <Link
              href="#features"
              className="text-sm font-medium text-muted-foreground hover:text-foreground transition-colors"
            >
              Features
            </Link>
            <Link
              href="#how-it-works"
              className="text-sm font-medium text-muted-foreground hover:text-foreground transition-colors"
            >
              How It Works
            </Link>
            <Link
              href="#artisans"
              className="text-sm font-medium text-muted-foreground hover:text-foreground transition-colors"
            >
              For Artisans
            </Link>
            <Link
              href="#faq"
              className="text-sm font-medium text-muted-foreground hover:text-foreground transition-colors"
            >
              FAQ
            </Link>
          </div>

          <Button className="bg-[#7A0000] hover:bg-[#4A0000] text-white rounded-full px-6">
            Coming Soon
          </Button>
        </div>
      </div>
    </nav>
  );
}

function HeroSection() {
  return (
    <section className="relative min-h-screen pt-32 pb-20 overflow-hidden">
      {/* Softer, more organic blobs for an artisanal feel */}
      <div className="absolute top-0 right-0 w-[800px] h-[800px] bg-gradient-to-br from-[#7A0000]/15 via-[#D4A020]/10 to-transparent rounded-full blur-[100px] animate-blob" />
      <div className="absolute bottom-0 left-0 w-[600px] h-[600px] bg-gradient-to-tr from-[#559826]/10 via-[#D4A020]/5 to-transparent rounded-full blur-[80px] animate-blob" style={{ animationDelay: "-7s" }} />
      <div className="absolute top-1/3 left-1/4 w-[400px] h-[400px] bg-gradient-to-br from-[#8B4513]/5 to-transparent rounded-full blur-[60px] animate-blob" style={{ animationDelay: "-14s" }} />

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 relative z-10">
        <div className="grid lg:grid-cols-2 gap-12 items-center">
          <div className="text-center lg:text-left">
            <Badge variant="secondary" className="mb-6 px-5 py-2.5 text-sm bg-white/50 backdrop-blur-md text-[#7A0000] border-[#EDD5BE] shadow-sm font-medium tracking-wide inline-flex items-center gap-2">
              <Sparkles className="w-3.5 h-3.5" /> Discover Authentic South African Craft
            </Badge>

            <h1 className="text-5xl md:text-6xl lg:text-7xl font-bold tracking-tight mb-6 text-[#3A1F10]">
              Handmade With
              <br />
              <span className="gradient-text italic">Heart & Soul.</span>
            </h1>

            <p className="text-lg md:text-xl text-muted-foreground max-w-lg mx-auto lg:mx-0 mb-8">
              Discover unique, handcrafted goods from South Africa&apos;s finest
              artisans. Every product on Artisan Lane tells a story of
              passion, tradition, and extraordinary craftsmanship.
            </p>

            <div className="flex flex-col sm:flex-row gap-4 justify-center lg:justify-start mb-8">
              <Link href="#" target="_blank" rel="noopener noreferrer">
                <Button
                  size="lg"
                  className="bg-[#7A0000] hover:bg-[#4A0000] text-white rounded-full px-8 h-14 text-base animate-pulse-glow w-full"
                >
                  <Apple className="w-5 h-5 mr-2" />
                  iOS — Coming Soon
                </Button>
              </Link>
              <Link href="#" target="_blank" rel="noopener noreferrer">
                <Button
                  size="lg"
                  variant="outline"
                  className="rounded-full px-8 h-14 text-base border-2 border-[#7A0000]/30 hover:bg-[#7A0000]/5 w-full"
                >
                  <svg className="w-5 h-5 mr-2" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M3,20.5V3.5C3,2.91 3.34,2.39 3.84,2.15L13.69,12L3.84,21.85C3.34,21.6 3,21.09 3,20.5M16.81,15.12L6.05,21.34L14.54,12.85L16.81,15.12M20.16,10.81C20.5,11.08 20.75,11.5 20.75,12C20.75,12.5 20.53,12.9 20.18,13.18L17.89,14.5L15.39,12L17.89,9.5L20.16,10.81M6.05,2.66L16.81,8.88L14.54,11.15L6.05,2.66Z"/>
                  </svg>
                  Android — Coming Soon
                </Button>
              </Link>
            </div>

            <div className="flex flex-wrap items-center justify-center lg:justify-start gap-6 text-sm text-muted-foreground">
              <span className="flex items-center gap-1">
                <Check className="w-4 h-4 text-[#559826]" /> Curated artisans
              </span>
              <span className="flex items-center gap-1">
                <Check className="w-4 h-4 text-[#559826]" /> Secure escrow payments
              </span>
              <span className="flex items-center gap-1">
                <Check className="w-4 h-4 text-[#559826]" /> 100% South African
              </span>
            </div>
          </div>

          <div className="relative flex justify-center">
            <div className="animate-float">
              <PhoneFrame
                src="/screenshot-home.png"
                alt="Artisan Lane home screen showing curated handmade products"
                priority
              />
            </div>
            <div className="absolute top-10 right-10 w-12 h-12 rounded-2xl bg-white/80 backdrop-blur shadow-lg flex items-center justify-center animate-float" style={{ animationDelay: "-1s" }}>
              <Gem className="w-6 h-6 text-[#7A0000]" />
            </div>
            <div className="absolute bottom-20 left-10 w-12 h-12 rounded-2xl bg-white/80 backdrop-blur shadow-lg flex items-center justify-center animate-float" style={{ animationDelay: "-2s" }}>
              <Palette className="w-6 h-6 text-[#D4A020]" />
            </div>
            <div className="absolute top-1/2 right-0 w-10 h-10 rounded-xl bg-white/80 backdrop-blur shadow-lg flex items-center justify-center animate-float" style={{ animationDelay: "-3s" }}>
              <Sparkles className="w-5 h-5 text-[#559826]" />
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

function FeaturesSection() {
  const features = [
    {
      icon: Search,
      title: "Discover Unique Crafts",
      description:
        "Browse a curated collection of handmade goods—from art & design and clothing to jewellery, beauty, home & living, and baby & kids. Every item is one of a kind.",
    },
    {
      icon: Store,
      title: "Dedicated Artisan Shops",
      description:
        "Each artisan gets their own branded storefront to showcase their craft, share their story, and build a loyal following.",
    },
    {
      icon: Shield,
      title: "Escrow-Protected Payments",
      description:
        "Buy with confidence. Your payment is held securely until you confirm receipt—protecting both buyers and artisans.",
    },
    {
      icon: Heart,
      title: "Favourites & Wishlists",
      description:
        "Save the pieces that catch your eye. Build wishlists and get notified when your favourite artisans add new creations.",
    },
    {
      icon: Truck,
      title: "Flexible Delivery Options",
      description:
        "Choose from Courier Guy, Pargo, PAXI pickup points, or collect directly from the maker at a local market.",
    },
    {
      icon: Sparkles,
      title: "Curated Quality",
      description:
        "Every artisan is reviewed before going live. This means no mass-produced items—just genuine, handcrafted goods you can trust.",
    },
  ];

  return (
    <section id="features" className="py-24 relative">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-16">
          <Badge
            variant="secondary"
            className="mb-4 px-4 py-2 text-sm bg-[#7A0000]/10 text-[#7A0000]"
          >
            Why Artisan Lane?
          </Badge>
          <h2 className="text-4xl md:text-5xl font-bold mb-4 text-[#3A1F10]">
            Not Just Another Marketplace.
            <br />
            <span className="gradient-text italic">A Celebration of Craft.</span>
          </h2>
        </div>

        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
          {features.map((feature, index) => (
            <Card
              key={index}
              className="group hover:shadow-xl hover:shadow-[#7A0000]/5 hover:-translate-y-2 transition-all duration-300 border-border/50"
            >
              <CardContent className="p-6">
                <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-[#7A0000]/10 to-[#D4A020]/10 flex items-center justify-center mb-4 group-hover:from-[#7A0000]/20 group-hover:to-[#D4A020]/20 transition-colors">
                  <feature.icon className="w-7 h-7 text-[#7A0000]" />
                </div>
                <h3 className="text-xl font-semibold mb-2">{feature.title}</h3>
                <p className="text-muted-foreground">{feature.description}</p>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    </section>
  );
}

function AppShowcaseSection() {
  return (
    <section id="how-it-works" className="py-24 bg-[#F7E4CC]/30 overflow-hidden">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-16">
          <Badge
            variant="secondary"
            className="mb-4 px-4 py-2 text-sm bg-[#7A0000]/10 text-[#7A0000]"
          >
            Experience the Marketplace
          </Badge>
          <h2 className="text-4xl md:text-5xl font-bold mb-4 text-[#3A1F10]">
            From Discovery to Doorstep,
            <br />
            <span className="gradient-text italic">Beautifully Simple.</span>
          </h2>
          <p className="text-lg text-muted-foreground max-w-2xl mx-auto">
            Browse artisan shops, explore handcrafted collections, and shop with complete confidence—all in one beautiful app.
          </p>
        </div>

        <div className="flex flex-col lg:flex-row items-center justify-center gap-8 lg:gap-12">
          <div className="relative lg:-translate-y-8">
            <SmallPhoneFrame
              src="/screenshot-shops.png"
              alt="Artisan Lane shop directory"
            />
            <Card className="absolute -bottom-4 -left-4 p-3 shadow-lg bg-white/90 backdrop-blur">
              <div className="flex items-center gap-2">
                <Store className="w-4 h-4 text-[#7A0000]" />
                <span className="text-sm font-medium">Browse Shops</span>
              </div>
            </Card>
          </div>

          <div className="relative z-10">
            <PhoneFrame
              src="/screenshot-home.png"
              alt="Artisan Lane home screen"
              className="scale-110"
            />
            <Card className="absolute -top-4 -right-4 p-3 shadow-lg bg-white/90 backdrop-blur">
              <div className="flex items-center gap-2">
                <Star className="w-4 h-4 text-[#D4A020] fill-current" />
                <span className="text-sm font-medium">Curated Picks</span>
              </div>
            </Card>
          </div>

          <div className="relative lg:translate-y-8">
            <SmallPhoneFrame
              src="/screenshot-checkout.png"
              alt="Artisan Lane product detail"
            />
            <Card className="absolute -bottom-4 -right-4 p-3 shadow-lg bg-white/90 backdrop-blur">
              <div className="flex items-center gap-2">
                <Shield className="w-4 h-4 text-[#559826]" />
                <span className="text-sm font-medium">Secure Checkout</span>
              </div>
            </Card>
          </div>
        </div>

        <div className="flex flex-wrap justify-center gap-3 mt-16">
          {["Art & Design", "Clothing", "Beauty", "Jewellery", "Home & Living", "Baby & Kids"].map((category) => (
            <Badge
              key={category}
              variant="outline"
              className="px-4 py-2 text-sm border-[#7A0000]/30 hover:bg-[#7A0000]/10 transition-colors cursor-pointer"
            >
              {category}
            </Badge>
          ))}
        </div>
      </div>
    </section>
  );
}

function ArtisanShopSection() {
  return (
    <section className="py-24 relative overflow-hidden">
      <div className="absolute inset-0 bg-gradient-to-br from-[#7A0000]/5 via-transparent to-[#D4A020]/5" />

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 relative z-10">
        <div className="grid lg:grid-cols-2 gap-16 items-center">
          <div className="relative flex justify-center order-2 lg:order-1">
            <div className="animate-float" style={{ animationDelay: "-2s" }}>
              <PhoneFrame
                src="/screenshot-product.png"
                alt="Artisan shop profile showing handmade products"
              />
            </div>
            <Card className="absolute top-20 -left-4 p-4 shadow-xl animate-float bg-white/90 backdrop-blur" style={{ animationDelay: "-1s" }}>
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-full bg-[#D4A020]/10 flex items-center justify-center">
                  <Palette className="w-5 h-5 text-[#D4A020]" />
                </div>
                <div>
                  <p className="font-semibold text-sm">50+ artisans</p>
                  <p className="text-xs text-muted-foreground">and growing</p>
                </div>
              </div>
            </Card>
            <Card className="absolute bottom-32 -right-4 p-4 shadow-xl animate-float bg-white/90 backdrop-blur" style={{ animationDelay: "-3s" }}>
              <div className="flex items-center gap-2">
                <Star className="w-4 h-4 text-[#D4A020] fill-current" />
                <span className="font-semibold">Handcrafted</span>
                <span className="text-sm text-muted-foreground">with love</span>
              </div>
            </Card>
          </div>

          <div className="order-1 lg:order-2">
            <Badge variant="secondary" className="mb-4 px-4 py-2 text-sm bg-[#7A0000]/10 text-[#7A0000]">
              Artisan Shops
            </Badge>
            <h2 className="text-4xl md:text-5xl font-bold mb-6 text-[#3A1F10]">
              Every Maker Has
              <br />
              <span className="gradient-text italic">A Story to Tell.</span>
            </h2>
            <p className="text-lg text-muted-foreground mb-8">
              Each artisan gets a dedicated shop space to showcase their brand, share their
              craft journey, and connect directly with buyers who value authentic, handmade goods.
            </p>

            <div className="space-y-4">
              {[
                { icon: Store, text: "Branded shop with cover image & logo" },
                { icon: ShoppingBag, text: "Full product catalogue management" },
                { icon: Users, text: "Build a loyal community of followers" },
              ].map((item, i) => (
                <div key={i} className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-full bg-[#7A0000]/10 flex items-center justify-center">
                    <item.icon className="w-5 h-5 text-[#7A0000]" />
                  </div>
                  <span className="font-medium">{item.text}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

function TrustSection() {
  return (
    <section className="py-24 bg-[#F7E4CC]/30">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid lg:grid-cols-2 gap-16 items-center">
          <div>
            <Badge variant="secondary" className="mb-4 px-4 py-2 text-sm bg-[#559826]/10 text-[#559826]">
              Secure & Trusted
            </Badge>
            <h2 className="text-4xl md:text-5xl font-bold mb-4 text-[#3A1F10]">
              Shop With Complete
              <br />
              <span className="gradient-text italic">Peace of Mind.</span>
            </h2>
            <p className="text-lg text-muted-foreground mb-8">
              Our escrow payment system protects every transaction. Your money is held
              securely until you confirm you&apos;ve received your order—so both buyers
              and artisans transact with confidence.
            </p>

            <div className="grid grid-cols-2 gap-4 mb-8">
              {[
                { value: "TradeSafe", label: "Secure gateway" },
                { value: "Escrow", label: "Protected funds" },
                { value: "4 options", label: "Shipping methods" },
                { value: "14 days", label: "Buyer protection" },
              ].map((stat, i) => (
                <Card key={i} className="p-4 text-center">
                  <p className="text-2xl font-bold text-[#7A0000]">{stat.value}</p>
                  <p className="text-sm text-muted-foreground">{stat.label}</p>
                </Card>
              ))}
            </div>

            <Button size="lg" className="bg-[#7A0000] hover:bg-[#4A0000] text-white rounded-full px-8">
              Start Shopping <ArrowRight className="w-4 h-4 ml-2" />
            </Button>
          </div>

          <div className="relative flex justify-center">
            <div className="animate-float" style={{ animationDelay: "-1s" }}>
              <PhoneFrame
                src="/screenshot-shop.png"
                alt="Secure checkout with escrow protection"
              />
            </div>
            <div className="absolute top-16 -right-4 bg-[#559826] text-white px-4 py-2 rounded-full font-semibold text-sm shadow-lg animate-float flex items-center gap-2">
              <Shield className="w-4 h-4" /> Escrow Protected
            </div>
            <Card className="absolute bottom-24 -left-8 p-4 shadow-xl bg-white/90 backdrop-blur">
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-[#7A0000] to-[#D4A020] flex items-center justify-center">
                  <Store className="w-6 h-6 text-white" />
                </div>
                <div>
                  <p className="font-semibold">Clay & Fire Studio</p>
                  <div className="flex items-center gap-1">
                    <Shield className="w-3 h-3 text-[#559826]" />
                    <span className="text-sm">Verified Artisan</span>
                  </div>
                </div>
              </div>
            </Card>
          </div>
        </div>
      </div>
    </section>
  );
}

function MarqueeSection() {
  const items = [
    { icon: Palette, label: "Curated South African crafts" },
    { icon: Sparkles, label: "Curated artisans" },
    { icon: Shield, label: "Escrow-protected payments" },
    { icon: Truck, label: "Nationwide delivery options" },
    { icon: Heart, label: "Handmade with heart & soul" },
  ];

  return (
    <div className="py-8 bg-[#7A0000]/5 border-y border-[#7A0000]/10 overflow-hidden">
      <div className="flex gap-16 animate-marquee">
        {[...items, ...items].map((item, index) => (
          <span
            key={index}
            className="whitespace-nowrap text-lg font-medium text-muted-foreground flex items-center gap-2"
          >
            <item.icon className="w-5 h-5 text-[#7A0000] shrink-0" />
            {item.label}
          </span>
        ))}
      </div>
    </div>
  );
}

function ForArtisansSection() {
  return (
    <section id="artisans" className="py-24 relative overflow-hidden">
      <div className="absolute inset-0 pattern-bg opacity-30" />
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 relative z-10">
        <div className="text-center mb-16">
          <Badge
            variant="secondary"
            className="mb-4 px-4 py-2 text-sm bg-[#D4A020]/10 text-[#8B4513]"
          >
            For Artisans
          </Badge>
          <h2 className="text-4xl md:text-5xl font-bold mb-4 text-[#3A1F10]">
            Turn Your Craft
            <br />
            <span className="gradient-text italic">Into a Thriving Business.</span>
          </h2>
          <p className="text-lg text-muted-foreground max-w-2xl mx-auto">
            Artisan Lane gives you the tools to reach buyers across South Africa—without
            the hassle of building your own e-commerce store.
          </p>
        </div>

        <div className="grid md:grid-cols-3 gap-8">
          {[
            {
              step: "01",
              title: "Apply to Join",
              description: "Submit an application with your business details, craft story, delivery method, and turnaround times. It's an open process — anyone can apply.",
              icon: ClipboardList,
            },
            {
              step: "02",
              title: "Get Reviewed & Set Up",
              description: "Our team reviews every application to ensure quality standards are met. Once approved, create your branded storefront and upload your products.",
              icon: Store,
            },
            {
              step: "03",
              title: "Start Selling",
              description: "Orders come in, you ship them out, and funds are released once the buyer confirms receipt. Simple as that.",
              icon: ShoppingBag,
            },
          ].map((item, i) => (
            <Card key={i} className="relative overflow-hidden group hover:-translate-y-2 transition-all duration-300">
              <div className="absolute top-0 right-0 w-20 h-20 bg-gradient-to-bl from-[#D4A020]/10 to-transparent" />
              <CardContent className="p-8">
                <span className="text-5xl font-bold text-[#D4A020]/20 block mb-4">{item.step}</span>
                <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-[#7A0000]/10 to-[#D4A020]/10 flex items-center justify-center mb-4">
                  <item.icon className="w-6 h-6 text-[#7A0000]" />
                </div>
                <h3 className="text-xl font-semibold mb-2">{item.title}</h3>
                <p className="text-muted-foreground">{item.description}</p>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    </section>
  );
}

function FAQSection() {
  const faqs = [
    {
      question: "What is Artisan Lane?",
      answer:
        "Artisan Lane is a curated mobile marketplace connecting South African artisans with buyers who appreciate unique, handmade goods. We focus on quality over quantity — every artisan is reviewed before going live, ensuring every product meets a high standard of craftsmanship.",
    },
    {
      question: "How does the escrow payment system work?",
      answer:
        "When you place an order, your payment is held securely via our escrow system powered by TradeSafe. The artisan is notified, ships your order, and once you confirm receipt, funds are released to the artisan. If you don't confirm within 14 days of delivery, funds are auto-released. Disputes can be raised any time before release.",
    },
    {
      question: "How can I become an artisan on Artisan Lane?",
      answer:
        "It's an open application process — anyone can apply. Simply register as an artisan in the app, tell us about your craft, how you fulfil orders, and your typical turnaround times. Our team reviews every application before you go live to ensure quality standards are met. Once approved, you can set up your shop and start selling.",
    },
    {
      question: "What shipping options are available?",
      answer:
        "We support multiple South African delivery options: Courier Guy for door-to-door delivery and locker-to-locker, Pargo for nationwide pickup points, PAXI for collection at PEP stores, and Market Pickup for in-person collection from the artisan at markets or events.",
    },
    {
      question: "Is Artisan Lane free to use for buyers?",
      answer:
        "Yes! The app is completely free to download and browse. You only pay for the products you purchase plus shipping. There are no subscription fees or hidden charges for buyers.",
    },
    {
      question: "What types of products can I find?",
      answer:
        "You'll find a diverse range of handcrafted goods across Art & Design, Clothing, Beauty, Jewellery, Home & Living, and Baby & Kids. You'll also find artisan-made preserves and sauces. Everything is handmade by verified South African artisans — no mass-produced items.",
    },
  ];

  return (
    <section id="faq" className="py-24 bg-[#F7E4CC]/30">
      <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-16">
          <Badge
            variant="secondary"
            className="mb-4 px-4 py-2 text-sm bg-[#7A0000]/10 text-[#7A0000]"
          >
            Questions?
          </Badge>
          <h2 className="text-4xl md:text-5xl font-bold">F.A.Q.</h2>
        </div>

        <Accordion type="single" collapsible className="space-y-4">
          {faqs.map((faq, index) => (
            <AccordionItem
              key={index}
              value={`item-${index}`}
              className="border rounded-xl px-6 bg-card"
            >
              <AccordionTrigger className="text-left font-semibold hover:text-[#7A0000] transition-colors">
                {faq.question}
              </AccordionTrigger>
              <AccordionContent className="text-muted-foreground">
                {faq.answer}
              </AccordionContent>
            </AccordionItem>
          ))}
        </Accordion>
      </div>
    </section>
  );
}

function CTASection() {
  return (
    <section className="py-24">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
        <Card className="relative overflow-hidden border-[#7A0000]/20">
          <div className="absolute top-0 right-0 w-80 h-80 bg-gradient-to-br from-[#7A0000]/20 to-[#D4A020]/15 rounded-full blur-3xl -translate-y-1/2 translate-x-1/2" />
          <div className="absolute bottom-0 left-0 w-60 h-60 bg-gradient-to-tr from-[#559826]/10 to-transparent rounded-full blur-3xl translate-y-1/2 -translate-x-1/2" />

          <CardContent className="relative p-12 text-center">
            <h2 className="text-4xl md:text-5xl font-bold mb-4">
              Support Local Artisans
            </h2>
            <p className="text-lg text-muted-foreground mb-8 max-w-lg mx-auto">
              Every purchase supports a South African artisan and their craft.
              Download Artisan Lane and discover the beauty of handmade.
            </p>

            <div className="flex flex-col sm:flex-row gap-4 justify-center mb-8">
              <Link href="#" target="_blank" rel="noopener noreferrer">
                <Button
                  size="lg"
                  className="bg-[#3A1F10] hover:bg-[#2a1510] text-white rounded-xl px-6 h-14 w-full"
                >
                  <Apple className="w-6 h-6 mr-3" />
                  <div className="text-left">
                    <span className="text-[10px] block opacity-70">Coming Soon on the</span>
                    <span className="font-semibold">App Store</span>
                  </div>
                </Button>
              </Link>
              <Link href="#" target="_blank" rel="noopener noreferrer">
                <Button
                  size="lg"
                  variant="outline"
                  className="rounded-xl px-6 h-14 border-2 w-full"
                >
                  <svg className="w-6 h-6 mr-3" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M3,20.5V3.5C3,2.91 3.34,2.39 3.84,2.15L13.69,12L3.84,21.85C3.34,21.6 3,21.09 3,20.5M16.81,15.12L6.05,21.34L14.54,12.85L16.81,15.12M20.16,10.81C20.5,11.08 20.75,11.5 20.75,12C20.75,12.5 20.53,12.9 20.18,13.18L17.89,14.5L15.39,12L17.89,9.5L20.16,10.81M6.05,2.66L16.81,8.88L14.54,11.15L6.05,2.66Z"/>
                  </svg>
                  <div className="text-left">
                    <span className="text-[10px] block opacity-70">Coming Soon on</span>
                    <span className="font-semibold">Google Play</span>
                  </div>
                </Button>
              </Link>
            </div>

            <div className="flex flex-wrap items-center justify-center gap-6 text-sm text-muted-foreground">
              <span className="flex items-center gap-1">
                <Check className="w-4 h-4 text-[#559826]" /> Free to download
              </span>
              <span className="flex items-center gap-1">
                <Check className="w-4 h-4 text-[#559826]" /> Curated quality
              </span>
              <span className="flex items-center gap-1">
                <Check className="w-4 h-4 text-[#559826]" /> Escrow protected
              </span>
            </div>
          </CardContent>
        </Card>
      </div>
    </section>
  );
}

function Footer() {
  return (
    <footer className="border-t border-[#EDD5BE] py-16">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-2 md:grid-cols-4 gap-8 mb-12">
          <div className="col-span-2">
            <Link href="/" className="flex items-center gap-2 mb-4">
              <Image
                src="/logo.png"
                alt="Artisan Lane Logo"
                width={32}
                height={32}
                className="rounded-lg"
              />
              <span className="text-xl font-bold">Artisan Lane</span>
            </Link>
            <p className="text-muted-foreground mb-6 max-w-xs">
              A curated craft marketplace celebrating South African artisans and their extraordinary handmade creations.
            </p>
            <div className="flex gap-4">
              <Link
                href="#"
                className="w-10 h-10 rounded-full bg-[#F7E4CC] flex items-center justify-center hover:bg-[#7A0000] hover:text-white transition-colors"
              >
                <svg className="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z"/>
                </svg>
              </Link>
              <Link
                href="#"
                className="w-10 h-10 rounded-full bg-[#F7E4CC] flex items-center justify-center hover:bg-[#7A0000] hover:text-white transition-colors"
              >
                <svg className="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zm0-2.163c-3.259 0-3.667.014-4.947.072-4.358.2-6.78 2.618-6.98 6.98-.059 1.281-.073 1.689-.073 4.948 0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98-1.281-.059-1.69-.073-4.949-.073zm0 5.838c-3.403 0-6.162 2.759-6.162 6.162s2.759 6.163 6.162 6.163 6.162-2.759 6.162-6.163c0-3.403-2.759-6.162-6.162-6.162zm0 10.162c-2.209 0-4-1.79-4-4 0-2.209 1.791-4 4-4s4 1.791 4 4c0 2.21-1.791 4-4 4zm6.406-11.845c-.796 0-1.441.645-1.441 1.44s.645 1.44 1.441 1.44c.795 0 1.439-.645 1.439-1.44s-.644-1.44-1.439-1.44z"/>
                </svg>
              </Link>
              <Link
                href="#"
                className="w-10 h-10 rounded-full bg-[#F7E4CC] flex items-center justify-center hover:bg-[#7A0000] hover:text-white transition-colors"
              >
                <svg className="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M19.59 6.69a4.83 4.83 0 0 1-3.77-4.25V2h-3.45v13.67a2.89 2.89 0 0 1-5.2 1.74 2.89 2.89 0 0 1 2.31-4.64 2.93 2.93 0 0 1 .88.13V9.4a6.84 6.84 0 0 0-1-.05A6.33 6.33 0 0 0 5 20.1a6.34 6.34 0 0 0 10.86-4.43v-7a8.16 8.16 0 0 0 4.77 1.52v-3.4a4.85 4.85 0 0 1-1-.1z"/>
                </svg>
              </Link>
            </div>
          </div>

          <div>
            <h4 className="font-semibold mb-4">Marketplace</h4>
            <ul className="space-y-3 text-muted-foreground">
              <li><Link href="#features" className="hover:text-[#7A0000] transition-colors">Features</Link></li>
              <li><Link href="#how-it-works" className="hover:text-[#7A0000] transition-colors">How It Works</Link></li>
              <li><Link href="#artisans" className="hover:text-[#7A0000] transition-colors">For Artisans</Link></li>
              <li><Link href="#" className="hover:text-[#7A0000] transition-colors">Categories</Link></li>
            </ul>
          </div>

          <div>
            <h4 className="font-semibold mb-4">Support</h4>
            <ul className="space-y-3 text-muted-foreground">
              <li><Link href="#faq" className="hover:text-[#7A0000] transition-colors">FAQ</Link></li>
              <li><Link href="mailto:support@artisanlane.co.za" className="hover:text-[#7A0000] transition-colors">Contact Us</Link></li>
              <li><Link href="#" className="hover:text-[#7A0000] transition-colors">Privacy Policy</Link></li>
              <li><Link href="#" className="hover:text-[#7A0000] transition-colors">Terms of Service</Link></li>
            </ul>
          </div>
        </div>

        <Separator className="mb-8 bg-[#EDD5BE]" />

        <div className="flex flex-col md:flex-row items-center justify-between gap-4">
          <p className="text-muted-foreground text-sm">
            © 2026 Artisan Lane. Celebrating South African craftsmanship.
          </p>
          <div className="flex items-center gap-2 text-sm text-muted-foreground">
            <Flag className="w-4 h-4 text-[#7A0000]" />
            <span>Made in South Africa</span>
          </div>
        </div>
      </div>
    </footer>
  );
}

export default function Home() {
  return (
    <main className="min-h-screen">
      <Navigation />
      <HeroSection />
      <FeaturesSection />
      <AppShowcaseSection />
      <ArtisanShopSection />
      <TrustSection />
      <MarqueeSection />
      <ForArtisansSection />
      <FAQSection />
      <CTASection />
      <Footer />
    </main>
  );
}
