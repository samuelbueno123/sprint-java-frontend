import 'package:dio/browser.dart';
import 'package:dio/dio.dart';

void enableBrowserCredentials(Dio dio) {
  dio.httpClientAdapter = BrowserHttpClientAdapter()..withCredentials = true;
}
