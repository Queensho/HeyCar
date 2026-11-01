/// Shared API selection for marketplace owner, business and admin entry points.
/// No credentials belong in this compile-time value.
const cepqontagApiBaseUrl = String.fromEnvironment(
  'CEPQONTAG_API_BASE_URL',
  defaultValue: 'https://heycar-api-185-165-46-213.nip.io',
);

/// Preserve existing production sessions; other API origins get separate storage.
String apiScopedPreferenceKey(String key) =>
    cepqontagApiBaseUrl == 'https://heycar-api-185-165-46-213.nip.io'
        ? key
        : '$key@${Uri.parse(cepqontagApiBaseUrl).origin}';
