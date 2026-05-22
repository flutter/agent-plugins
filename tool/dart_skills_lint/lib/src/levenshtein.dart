import 'dart:math' as math;

/// Plain Levenshtein edit distance over runes. O(n*m) time, O(m) space.
///
/// Used by sibling-suggestion logic to score how close an existing filename
/// is to a missing one. Lifted into its own file so the rule that consumes
/// it stays focused on the rule contract and so the function is easy to
/// unit-test in isolation.
int levenshtein(String a, String b) {
  if (a == b) {
    return 0;
  }
  if (a.isEmpty) {
    return b.length;
  }
  if (b.isEmpty) {
    return a.length;
  }

  final List<int> aCodes = a.runes.toList();
  final List<int> bCodes = b.runes.toList();

  var previous = List<int>.generate(bCodes.length + 1, (j) => j);
  var current = List<int>.filled(bCodes.length + 1, 0);
  for (var i = 1; i <= aCodes.length; i++) {
    current[0] = i;
    for (var j = 1; j <= bCodes.length; j++) {
      final cost = aCodes[i - 1] == bCodes[j - 1] ? 0 : 1;
      final int del = previous[j] + 1;
      final int ins = current[j - 1] + 1;
      final int sub = previous[j - 1] + cost;
      current[j] = math.min(math.min(del, ins), sub);
    }
    final swap = previous;
    previous = current;
    current = swap;
  }
  return previous[bCodes.length];
}
