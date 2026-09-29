/// Picks the Arabic plural form for [count] (CLDR rules):
/// 0 → zero, 1 → one, 2 → two, n%100 in 3..10 → few, n%100 in 11..99 → many,
/// everything else (100, 101, 102, …) → other.
String arabicPlural(
  int count, {
  required String zero,
  required String one,
  required String two,
  required String few,
  required String many,
  required String other,
}) {
  if (count == 0) return zero;
  if (count == 1) return one;
  if (count == 2) return two;
  final mod = count % 100;
  if (mod >= 3 && mod <= 10) return few;
  if (mod >= 11 && mod <= 99) return many;
  return other;
}
