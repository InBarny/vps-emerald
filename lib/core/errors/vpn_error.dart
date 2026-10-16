enum VpnErrorKind {
  config,
  binaryNotFound,
  permissions,
  processStart,
  processRuntime,
  disconnectedUnexpectedly,
  platformUnsupported,
  splitTunneling,
  unknown,
}

class VpnError implements Exception {
  VpnError(this.kind, this.message, {this.details});

  final VpnErrorKind kind;
  final String message;
  final Object? details;

  @override
  String toString() =>
      'VpnError(kind: $kind, message: $message, details: $details)';
}
