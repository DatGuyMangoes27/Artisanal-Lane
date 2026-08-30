export function getDailyProductRotationSeed(date = new Date()) {
  return date.toISOString().slice(0, 10);
}

function rotationScore(value: string) {
  let hash = 2166136261;
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}

export function rotateProductsForSeed<T extends { id: string }>(
  products: T[],
  seed: string,
) {
  return [...products].sort(
    (left, right) =>
      rotationScore(`${seed}:${left.id}`) - rotationScore(`${seed}:${right.id}`) ||
      left.id.localeCompare(right.id),
  );
}
