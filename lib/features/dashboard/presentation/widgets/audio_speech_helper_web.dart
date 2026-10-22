import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

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
  static bool get isTtsSupported {
    try {
      return globalContext.has('speechSynthesis');
    } catch (_) {
      return false;
    }
  }

  static bool get isSttSupported {
    try {
      return globalContext.has('SpeechRecognition') ||
          globalContext.has('webkitSpeechRecognition');
    } catch (_) {
      return false;
    }
  }

  static Future<bool> speak(
    String text, {
    String languageName = 'Inglês',
    double rate = 1.0,
  }) async {
    if (!isTtsSupported || text.trim().isEmpty) return false;
    try {
      final synth = web.window.speechSynthesis;
      synth.cancel();
      final utterance = web.SpeechSynthesisUtterance(text.trim());
      utterance.lang = mapLanguageToBcp47(languageName);
      utterance.rate = rate;
      synth.speak(utterance);
      return true;
    } catch (_) {
      return false;
    }
  }

  static void stopSpeaking() {
    if (!isTtsSupported) return;
    try {
      web.window.speechSynthesis.cancel();
    } catch (_) {}
  }

  static Future<String?> recognizeSpeech({
    String languageName = 'Inglês',
    void Function(String status)? onStatus,
  }) async {
    if (!isSttSupported) {
      onStatus?.call(
        'Seu navegador não oferece suporte ao reconhecimento de voz (Web Speech API). Use a resposta escrita ou a alternativa acessível.',
      );
      return null;
    }

    final completer = Completer<String?>();
    try {
      final ctor = (globalContext.getProperty('SpeechRecognition'.toJS) ??
              globalContext.getProperty('webkitSpeechRecognition'.toJS))
          as JSFunction?;
      if (ctor == null) {
        onStatus?.call('Reconhecimento de voz indisponível neste navegador.');
        return null;
      }

      final recognition = ctor.callAsConstructor<JSObject>();
      recognition.setProperty('lang'.toJS, mapLanguageToBcp47(languageName).toJS);
      recognition.setProperty('interimResults'.toJS, false.toJS);
      recognition.setProperty('maxAlternatives'.toJS, 1.toJS);

      onStatus?.call('Ouvindo... Fale próximo ao microfone.');

      recognition.setProperty(
        'onresult'.toJS,
        ((JSObject event) {
          try {
            final results = event.getProperty('results'.toJS) as JSObject?;
            final firstResult = results?.getProperty(0.toJS) as JSObject?;
            final firstAlt = firstResult?.getProperty(0.toJS) as JSObject?;
            final transcript =
                (firstAlt?.getProperty('transcript'.toJS) as JSString?)?.toDart;
            if (!completer.isCompleted) {
              onStatus?.call(
                transcript != null && transcript.trim().isNotEmpty
                    ? 'Fala transcrita com sucesso!'
                    : 'Nenhuma fala detectada.',
              );
              completer.complete(transcript?.trim());
            }
          } catch (e) {
            if (!completer.isCompleted) {
              onStatus?.call('Falha ao processar o áudio capturado.');
              completer.complete(null);
            }
          }
        }).toJS,
      );

      recognition.setProperty(
        'onerror'.toJS,
        ((JSObject event) {
          final errorCode =
              (event.getProperty('error'.toJS) as JSString?)?.toDart ?? 'erro';
          final friendly = switch (errorCode) {
            'not-allowed' || 'service-not-allowed' =>
              'Permissão de microfone negada. Autorize o microfone no navegador ou use a alternativa acessível.',
            'no-speech' =>
              'Nenhuma fala foi detectada. Tente novamente ou digite sua resposta.',
            'audio-capture' =>
              'Nenhum microfone encontrado. Use a alternativa acessível abaixo.',
            _ =>
              'Não foi possível transcrever o áudio ($errorCode). Você pode digitar a resposta ou pular o áudio.',
          };
          onStatus?.call(friendly);
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        }).toJS,
      );

      recognition.setProperty(
        'onend'.toJS,
        ((JSAny? _) {
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        }).toJS,
      );

      recognition.callMethod('start'.toJS);
    } catch (e) {
      onStatus?.call(
        'Erro ao iniciar captura de voz. Use o campo de texto ou a alternativa acessível.',
      );
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }

    return completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        onStatus?.call(
          'Tempo de escuta esgotado. Tente novamente ou digite sua resposta.',
        );
        return null;
      },
    );
  }
}
