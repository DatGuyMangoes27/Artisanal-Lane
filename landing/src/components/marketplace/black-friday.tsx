import Link from "next/link";

/** The black "Black Friday Deal" sticker shown on products on sale. */
export function BlackFridaySticker({ className = "" }: { className?: string }) {
  return (
    <span
      className={`inline-flex -rotate-6 flex-col items-center rounded-lg border border-[#D4A020] bg-[#111111] px-2.5 py-1.5 leading-none text-white shadow-md ${className}`}
    >
      <span className="text-[10px] font-extrabold tracking-wider">BLACK</span>
      <span className="text-[10px] font-extrabold tracking-wider">FRIDAY</span>
      <span className="mt-0.5 text-[8px] font-extrabold tracking-[0.2em] text-[#D4A020]">DEAL</span>
    </span>
  );
}

/** "Black Friday Specials Now Live" banner for Home and Shop. */
export function BlackFridayBanner() {
  return (
    <Link
      href="/shop"
      className="mx-auto my-4 flex max-w-[1440px] items-center justify-between gap-4 rounded-3xl bg-[#111111] px-6 py-5 text-white sm:mx-8 sm:px-10"
    >
      <span>
        <span className="block text-[10px] font-bold uppercase tracking-[0.24em] text-[#D4A020]">
          Black Friday · 27–30 Nov
        </span>
        <span className="mt-1 block font-serif text-2xl font-bold sm:text-3xl">
          Black Friday Specials Now Live
        </span>
        <span className="mt-1 block text-sm text-white/70 underline">Shop the deals</span>
      </span>
      <BlackFridaySticker className="shrink-0 scale-125" />
    </Link>
  );
}
