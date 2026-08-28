/// A fixture that must pass every purity rule.
int doubleValue(int value) => value * 2;

class Doubler {
  const Doubler(this.factor);

  final int factor;

  int apply(int value) => value * factor;
}
