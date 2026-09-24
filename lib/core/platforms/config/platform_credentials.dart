/// Keeta app credentials, issued by Keeta after the NDA.
///
/// `appSecret` is only used locally to compute `sig`; it is never sent.
final class KeetaCredentials {
  const KeetaCredentials({required this.appId, required this.appSecret});

  final int appId;
  final String appSecret;

  bool get isComplete => appId > 0 && appSecret.isNotEmpty;
}

enum HsEnvironment {
  production('https://hungerstation.partner.deliveryhero.io'),
  sandbox('https://sandbox.partner.deliveryhero.io');

  const HsEnvironment(this.baseUrl);

  final String baseUrl;
}

/// HungerStation Partner API credentials (Partner Portal → All Settings →
/// Shop Integrations Plugin). Production and sandbox credentials differ.
final class HungerStationCredentials {
  const HungerStationCredentials({
    required this.clientId,
    required this.clientSecret,
    required this.chainId,
    this.vendorId = '',
    this.environment = HsEnvironment.production,
  });

  final String clientId;
  final String clientSecret;

  /// The brand/account (`chain_id` in every path).
  final String chainId;

  /// Default outlet (`vendor_id`) when a call doesn't name one.
  final String vendorId;

  final HsEnvironment environment;

  bool get isComplete =>
      clientId.isNotEmpty && clientSecret.isNotEmpty && chainId.isNotEmpty;
}
