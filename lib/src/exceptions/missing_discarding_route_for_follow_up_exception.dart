class MissingDiscardingRouteForFollowUpException implements Exception {
  Type guardType;

  MissingDiscardingRouteForFollowUpException(this.guardType);

  @override
  String toString() =>
      "A followUp route was defined for $guardType but no routes were found that are `discardedBy` $guardType.";
}
