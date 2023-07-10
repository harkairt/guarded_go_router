class ShieldRouteMissingException implements Exception {
  Type guardType;

  ShieldRouteMissingException(this.guardType);

  @override
  String toString() => "Shield route is not defined for $guardType";
}
