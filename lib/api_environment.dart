/// Production behavior is unchanged unless a test build explicitly overrides it.
const apiBaseUrl = String.fromEnvironment('CEPQONTAG_API_BASE_URL',
    defaultValue: 'https://heycar-api-185-165-46-213.nip.io');
const isStagingBuild = bool.fromEnvironment('CEPQONTAG_STAGING');

void validateApiEnvironment() {
  if (!isStagingBuild) return;
  final u = Uri.tryParse(apiBaseUrl);
  const productionHosts = {
    'heycar-api-185-165-46-213.nip.io',
    'cepqar.com',
    'www.cepqar.com',
    'cepqontag.com',
    'www.cepqontag.com'
  };
  if (u == null ||
      u.scheme != 'https' ||
      u.host.isEmpty ||
      u.userInfo.isNotEmpty ||
      u.hasQuery ||
      u.hasFragment ||
      productionHosts.contains(u.host.toLowerCase())) {
    throw StateError(
        'Staging builds require an explicit HTTPS staging API origin.');
  }
}
