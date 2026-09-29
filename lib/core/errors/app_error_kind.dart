/// What went wrong, from the user's point of view. Drives the icon, colour,
/// title and advice shown for an error.
enum AppErrorKind {
  /// The server could not be reached (no network, backend down, wrong URL).
  offline,

  /// The server was reached but did not answer in time.
  timeout,

  /// Credentials were rejected.
  unauthorized,

  /// Credentials or settings are missing — retrying won't help.
  notConfigured,

  /// Too many requests; wait before retrying.
  rateLimited,

  /// The server failed internally (5xx) or answered in an unexpected shape.
  server,

  /// The server refused the request (4xx / business rule).
  rejected,

  unknown,
}
