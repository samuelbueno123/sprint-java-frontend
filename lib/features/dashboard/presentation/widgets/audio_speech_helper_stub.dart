String mapLanguageToBcp47(String languageName) {
  final normalized = languageName.trim().toLowerCase();
  if (normalized.contains('ingl') || normalized.contains('english')) {
    return 'en-US';
  }
  if (normalized.contains('espan') || normalized.contains('spanish')) {
    return 'es-ES';
  }
  if (normalized.contains('franc') || normalized.contains('french')) {
    return 'fr-FR';
  }
  if (normalized.contains('alem') || normalized.contains('german')) {
    return 'de-DE';
  }
  if (normalized.contains('ital')) {
    return 'it-IT';
  }
  if (normalized.contains('japon') || normalized.contains('japan')) {
    return 'ja-JP';
  }
  if (normalized.contains('portug')) {
    return 'pt-BR';
  }
  return 'en-US';
}

class AudioSpeechHelper {
  static bool get isTtsSupported => false;

  static bool get isSttSupported => false;

  static Future<bool> speak(
    String text, {
    String languageName = 'Inglês',
    double rate = 1.0,
  }) async {
    return false;
  }

  static void stopSpeaking() {}

  static Future<String?> recognizeSpeech({
    String languageName = 'Inglês',
    void Function(String status)? onStatus,
  }) async {
    onStatus?.call(
      'Reconhecimento de voz nativo indisponível nesta plataforma. Use a transcrição por texto ou o modo acessível.',
    );
    return null;
  }
}
