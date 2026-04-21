int mathImul32(int a, int b) {
  return ((a * b) & 0xFFFFFFFF).toSigned(32);
}

int hashStringToInt(String input) {
  var h = 2166136261;
  for (var i = 0; i < input.length; i++) {
    h = (h ^ input.codeUnitAt(i)) & 0xFFFFFFFF;
    h = mathImul32(h, 16777619);
  }
  return h.abs();
}
