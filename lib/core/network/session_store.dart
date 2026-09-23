/// JWT da sessão atual. O token fica apenas em memória durante a execução do app.
class SessionStore {
  SessionStore._();

  static String? _accessToken;

  static String? get accessToken => _accessToken;

  static void setAccessToken(String token) {
    _accessToken = token.isEmpty ? null : token;
  }

  static void clear() {
    _accessToken = null;
  }
}
