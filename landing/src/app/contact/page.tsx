import type { Metadata } from "next";
import Link from "next/link";
import Image from "next/image";
import { Mail, MapPin, Clock, ArrowLeft, MessageSquare, Instagram } from "lucide-react";
import { Card, CardContent } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";

export const metadata: Metadata = {
  title: "Contact Us — Artisan Lane",
  description:
    "Get in touch with the Artisan Lane team. We're here to help buyers and artisans with any questions.",
};

export default function ContactPage() {
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
        <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
          <h1 className="text-4xl md:text-5xl font-bold mb-4 text-[#3A1F10]">
            Get in Touch
          </h1>
          <p className="text-lg text-muted-foreground mb-12">
            Whether you&apos;re a buyer with a question or an artisan looking to join, we&apos;d love to hear from you.
          </p>

          <div className="grid sm:grid-cols-2 gap-6 mb-12">
            <Card>
              <CardContent className="p-6">
                <div className="w-12 h-12 rounded-2xl bg-[#7A0000]/10 flex items-center justify-center mb-4">
                  <Mail className="w-6 h-6 text-[#7A0000]" />
                </div>
                <h3 className="text-lg font-semibold mb-1">Email Us</h3>
                <p className="text-muted-foreground text-sm mb-3">
                  For general enquiries, support, or partnership opportunities.
                </p>
                <a
                  href="mailto:hello@artisanlane.co.za"
                  className="text-[#7A0000] font-medium hover:underline"
                >
                  hello@artisanlane.co.za
                </a>
              </CardContent>
            </Card>

            <Card>
              <CardContent className="p-6">
                <div className="w-12 h-12 rounded-2xl bg-[#7A0000]/10 flex items-center justify-center mb-4">
                  <MessageSquare className="w-6 h-6 text-[#7A0000]" />
                </div>
                <h3 className="text-lg font-semibold mb-1">WhatsApp</h3>
                <p className="text-muted-foreground text-sm mb-3">
                  Quick questions? Chat with us on WhatsApp during business hours.
                </p>
                <a
                  href="https://wa.me/27000000000"
                  className="text-[#7A0000] font-medium hover:underline"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  Send a message
                </a>
              </CardContent>
            </Card>

            <Card>
              <CardContent className="p-6">
                <div className="w-12 h-12 rounded-2xl bg-[#7A0000]/10 flex items-center justify-center mb-4">
                  <Instagram className="w-6 h-6 text-[#7A0000]" />
                </div>
                <h3 className="text-lg font-semibold mb-1">Social Media</h3>
                <p className="text-muted-foreground text-sm mb-3">
                  Follow us for updates, new artisan spotlights, and behind-the-scenes content.
                </p>
                <span className="text-[#7A0000] font-medium">@artisanlane</span>
              </CardContent>
            </Card>

            <Card>
              <CardContent className="p-6">
                <div className="w-12 h-12 rounded-2xl bg-[#7A0000]/10 flex items-center justify-center mb-4">
                  <Clock className="w-6 h-6 text-[#7A0000]" />
                </div>
                <h3 className="text-lg font-semibold mb-1">Business Hours</h3>
                <p className="text-muted-foreground text-sm mb-3">
                  We aim to respond to all enquiries within 24 hours.
                </p>
                <p className="text-sm font-medium">Mon – Fri: 08:00 – 17:00 SAST</p>
              </CardContent>
            </Card>
          </div>

          <Separator className="mb-12 bg-[#EDD5BE]" />

          <div className="text-center">
            <div className="w-12 h-12 rounded-2xl bg-[#D4A020]/10 flex items-center justify-center mx-auto mb-4">
              <MapPin className="w-6 h-6 text-[#D4A020]" />
            </div>
            <h3 className="text-lg font-semibold mb-2">Based in South Africa</h3>
            <p className="text-muted-foreground max-w-md mx-auto">
              Artisan Lane is proudly South African. We operate remotely across the country,
              supporting artisans from Cape Town to Limpopo.
            </p>
          </div>
        </div>
      </section>
    </main>
  );
}
