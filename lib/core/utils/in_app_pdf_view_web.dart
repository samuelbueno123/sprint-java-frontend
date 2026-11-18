import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class InAppPdfView extends StatefulWidget {
  const InAppPdfView({
    super.key,
    required this.bytes,
    required this.fileName,
    this.onDownload,
  });

  final Uint8List bytes;
  final String fileName;
  final VoidCallback? onDownload;

  @override
  State<InAppPdfView> createState() => _InAppPdfViewState();
}

class _InAppPdfViewState extends State<InAppPdfView> {
  static int _viewCounter = 0;

  late String _viewType;
  late String _blobUrl;

  @override
  void initState() {
    super.initState();
    _initIframe();
  }

  void _initIframe() {
    _viewCounter++;
    _viewType = 'duolinfo-pdf-viewer-$_viewCounter';
    final blob = web.Blob(
      [widget.bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'application/pdf'),
    );
    _blobUrl = web.URL.createObjectURL(blob);
    final urlSnapshot = _blobUrl;
    final title = widget.fileName;

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = web.document.createElement('iframe')
          as web.HTMLIFrameElement
        ..src = urlSnapshot
        ..title = title
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = 'none'
        ..style.backgroundColor = '#1e293b';
      return iframe;
    });
  }

  @override
  void didUpdateWidget(covariant InAppPdfView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bytes, widget.bytes)) {
      web.URL.revokeObjectURL(_blobUrl);
      _initIframe();
    }
  }

  @override
  void dispose() {
    web.URL.revokeObjectURL(_blobUrl);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
