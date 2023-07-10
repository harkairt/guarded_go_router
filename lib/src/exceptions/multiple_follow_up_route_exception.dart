class MultipleFollowUpRouteException implements Exception {
  Type guardType;

  MultipleFollowUpRouteException(this.guardType);

  @override
  String toString() => "Guard $guardType has multiple followUp routes";
}
