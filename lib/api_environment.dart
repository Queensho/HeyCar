/// Production behavior is unchanged unless a test build explicitly overrides it.
const apiBaseUrl = String.fromEnvironment('CEPQONTAG_API_BASE_URL',
    defaultValue: 'https://heycar-api-185-165-46-213.nip.io');
const isStagingBuild = bool.fromEnvironment('CEPQONTAG_STAGING');

const isStagingQaFcm = bool.fromEnvironment('CEPQONTAG_STAGING_QA_FCM');
const stagingFirebaseProjectId = 'cepqontag-staging';
const stagingFirebaseSenderId = '603919772851';
void validateApiEnvironment() {
  if (isStagingQaFcm && (!isStagingBuild || apiBaseUrl != 'https://staging-api-185-165-46-213.nip.io')) {
    throw StateError('QA FCM requires the isolated staging API and build.');
  }
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
