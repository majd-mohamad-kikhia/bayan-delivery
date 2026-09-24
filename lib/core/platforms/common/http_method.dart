enum HttpMethod {
  get('GET'),
  post('POST'),
  put('PUT'),
  patch('PATCH'),
  delete('DELETE');

  const HttpMethod(this.wire);

  /// Verb as sent to the executor.
  final String wire;

  /// The executor sends `params` as a query string for GET, a JSON body
  /// otherwise.
  bool get sendsParamsAsQuery => this == HttpMethod.get;
}
