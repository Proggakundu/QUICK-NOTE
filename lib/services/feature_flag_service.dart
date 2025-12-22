class FeatureFlagService {
  static final FeatureFlagService _instance = FeatureFlagService._internal();
  factory FeatureFlagService() => _instance;
  FeatureFlagService._internal();

  final Map<String, bool> _flags = {
    'location-tagging': true,
    'dark-mode': false,
    'auto-save': true,
    'notifications': false,
    'offline-mode': false, // false = online mode (default)
  };

  Future<bool> isEnabled(String flagName) async {
    return _flags[flagName] ?? false;
  }

  Future<void> setFlag(String key, bool value) async {
    _flags[key] = value;
  }

  Map<String, bool> getAllFlags() {
    return Map.from(_flags);
  }
}

final featureFlagService = FeatureFlagService();