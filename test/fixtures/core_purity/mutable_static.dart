/// A fixture that must fail: mutable static state inside the core (AD-3).
class Tally {
  static int total = 0;

  static void add(int amount) {
    total += amount;
  }
}
