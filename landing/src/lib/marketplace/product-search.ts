// Relevance matching for marketplace product search.
//
// Word based, never raw substring: a query word matches a product word when
// they are equal (ignoring simple plurals, so "rings" finds "ring") or when
// the product word starts with it ("neckla" finds "necklace"). A query word
// that only appears inside another word ("rings" in "earrings"/"strings")
// does not match. Every query word must match somewhere; each scores by its
// best field: title > tags/category/subcategory > shop name > description.
//
// Mirrors lib/features/buyer/utils/product_search.dart (app) and
// public.search_buyer_products (SQL) — keep the three in step.

const maxQueryWords = 8;
const nonWord = /[^\p{L}\p{N}]+/u;

export type SearchableProduct = {
  title: string;
  description?: string | null;
  tags?: readonly string[] | null;
  category?: { name: string } | null;
  subcategory?: { name: string } | null;
  shop?: { name: string } | null;
};

export function searchWords(text: string | null | undefined): string[] {
  if (!text) return [];
  return text.toLowerCase().split(nonWord).filter((word) => word.length > 0);
}

export function searchQueryWords(query: string | null | undefined): string[] {
  return Array.from(new Set(searchWords(query))).slice(0, maxQueryWords);
}

export function singularSearchWord(word: string): string {
  if (word.length > 4 && word.endsWith("ies")) {
    return `${word.slice(0, -3)}y`;
  }
  if (
    word.length > 4 &&
    ["sses", "xes", "ches", "shes", "zes"].some((suffix) => word.endsWith(suffix))
  ) {
    return word.slice(0, -2);
  }
  if (
    word.length > 3 &&
    word.endsWith("s") &&
    !word.endsWith("ss") &&
    !word.endsWith("us") &&
    !word.endsWith("is")
  ) {
    return word.slice(0, -1);
  }
  return word;
}

/** 2 = exact word (plural-insensitive), 1 = word prefix, 0 = no match. */
export function matchSearchWord(queryWord: string, words: readonly string[]): 0 | 1 | 2 {
  const singularQuery = singularSearchWord(queryWord);
  let best: 0 | 1 = 0;
  for (const word of words) {
    if (word === queryWord || singularSearchWord(word) === singularQuery) return 2;
    if (queryWord.length >= 2 && word.startsWith(queryWord)) best = 1;
  }
  return best;
}

function fieldScore(match: 0 | 1 | 2, exact: number, prefix: number) {
  return match === 2 ? exact : match === 1 ? prefix : 0;
}

function scoreWords(product: SearchableProduct, queryWords: string[]): number {
  if (queryWords.length === 0) return 0;
  const title = searchWords(product.title);
  const meta = [
    ...(product.tags ?? []).flatMap((tag) => searchWords(tag)),
    ...searchWords(product.category?.name),
    ...searchWords(product.subcategory?.name),
  ];
  const shop = searchWords(product.shop?.name);
  const description = searchWords(product.description);

  let total = 0;
  for (const word of queryWords) {
    const best = Math.max(
      fieldScore(matchSearchWord(word, title), 100, 80),
      fieldScore(matchSearchWord(word, meta), 60, 50),
      fieldScore(matchSearchWord(word, shop), 40, 30),
      fieldScore(matchSearchWord(word, description), 20, 15),
    );
    if (best === 0) return 0;
    total += best;
  }
  if (title.join(" ").startsWith(queryWords.join(" "))) total += 10;
  return total;
}

/** Relevance score of a product for a query; 0 means "not a match". */
export function productSearchScore(product: SearchableProduct, query: string): number {
  return scoreWords(product, searchQueryWords(query));
}

/**
 * Keeps only products matching the query, ordered by relevance; equal
 * scores keep their incoming order.
 */
export function rankProductSearch<T extends SearchableProduct>(products: readonly T[], query: string): T[] {
  const queryWords = searchQueryWords(query);
  if (queryWords.length === 0) return [];
  return products
    .map((product, index) => ({ product, index, score: scoreWords(product, queryWords) }))
    .filter((entry) => entry.score > 0)
    .sort((a, b) => b.score - a.score || a.index - b.index)
    .map((entry) => entry.product);
}

/**
 * Stems to pre-filter candidates with (ilike '%stem%'), plus raw words for an
 * exact tag overlap. Letters/digits only, so they are safe inside PostgREST
 * filter strings.
 */
export function searchCandidateTerms(query: string) {
  const words = searchQueryWords(query);
  const stems = Array.from(new Set(words.map(singularSearchWord)));
  return { words, stems, tags: Array.from(new Set([...words, ...stems])) };
}
