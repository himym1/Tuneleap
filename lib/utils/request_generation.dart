class RequestGeneration {
  int _generation = 0;

  int begin() => ++_generation;
  int get current => _generation;

  void invalidate() => _generation++;

  bool isCurrent(int generation) => generation == _generation;
}
