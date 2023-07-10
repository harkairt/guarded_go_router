class MultipleShieldRouteException implements Exception {
  Type guardType;

  MultipleShieldRouteException(this.guardType);

  @override
  String toString() => "Guard $guardType has multiple shield routes";
}
