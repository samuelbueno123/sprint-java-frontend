import 'local_image_picker_stub.dart'
    if (dart.library.io) 'local_image_picker_io.dart'
    if (dart.library.js_interop) 'local_image_picker_web.dart'
    as picker;

class LocalImagePickerHelper {
  LocalImagePickerHelper._();

  static Future<String?> pickLocalImage() => picker.pickLocalImage();
}
