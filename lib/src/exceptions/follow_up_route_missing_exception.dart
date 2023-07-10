class FollowUpRouteMissingException implements Exception {
  Type guardType;

  FollowUpRouteMissingException(this.guardType);

  @override
  String toString() => "followUp route is not defined for $guardType.";
}
