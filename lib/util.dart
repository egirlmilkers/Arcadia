import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:toastification/toastification.dart';

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

class WindowsInjector {
  static WindowsInjector get instance => _instance;
  static final WindowsInjector _instance = WindowsInjector._();

  bool _startInjectKeyData = false;

  WindowsInjector._();

  void injectKeyData() {
    // Wait a second to inject KeyData callback
    Future.delayed(const Duration(seconds: 1), _injectkeyData);
  }

  void _injectkeyData() {
    final KeyDataCallback? callback = PlatformDispatcher.instance.onKeyData;
    if (callback == null) {
      // Failed to get the built-in callback, skip the injection.
      return;
    }
    PlatformDispatcher.instance.onKeyData = (data) {
      if (!_startInjectKeyData &&
          data.physical == 0x1600000000 &&
          data.logical == 0x200000100 &&
          data.type == KeyEventType.down &&
          !data.synthesized) {
        // Change to Control Left key down event.
        data = KeyData(
          timeStamp: data.timeStamp,
          type: KeyEventType.down,
          physical: 0x700e0,
          logical: 0x200000100,
          character: null,
          synthesized: false,
        );
        _startInjectKeyData = true;
      } else if (_startInjectKeyData &&
          data.physical == 0 &&
          data.logical == 0 &&
          data.type == KeyEventType.down &&
          !data.synthesized) {
        return true;
      } else if (_startInjectKeyData &&
          data.physical == 0x1600000000 &&
          data.logical == 0x200000100 &&
          data.type == KeyEventType.up &&
          !data.synthesized) {
        // Change to V key down event.
        data = KeyData(
          timeStamp: data.timeStamp,
          type: KeyEventType.down,
          physical: 0x70019,
          logical: 0x76,
          character: null,
          synthesized: false,
        );
      } else if (_startInjectKeyData &&
          data.physical == 0x1600000000 &&
          data.logical == 0x200000100 &&
          data.type == KeyEventType.down &&
          data.synthesized) {
        // Change to V key up event.
        data = KeyData(
          timeStamp: data.timeStamp,
          type: KeyEventType.up,
          physical: 0x70019,
          logical: 0x76,
          character: null,
          synthesized: false,
        );
      } else if (_startInjectKeyData &&
          data.physical == 0x1600000000 &&
          data.logical == 0x200000100 &&
          data.type == KeyEventType.up &&
          data.synthesized) {
        // Change to Control Left key up event.
        data = KeyData(
          timeStamp: data.timeStamp,
          type: KeyEventType.up,
          physical: 0x700e0,
          logical: 0x200000100,
          character: null,
          synthesized: false,
        );
        _startInjectKeyData = false;
      } else {
        _startInjectKeyData = false;
      }
      return callback(data);
    };
  }
}

ToastificationItem showCopiedToast(BuildContext context, ColorScheme theme) {
  return toastification.show(
    context: context,
    type: ToastificationType.success,
    style: ToastificationStyle.simple,
    title: const Text("Copied to clipboard!"),
    alignment: Alignment.topCenter,
    padding: EdgeInsets.only(left: 8, right: 8),
    backgroundColor: theme.tertiaryContainer,
    foregroundColor: theme.onTertiaryContainer,
    autoCloseDuration: const Duration(seconds: 1, milliseconds: 300),
    animationBuilder: (context, animation, alignment, child) {
      return FadeTransition(opacity: animation, child: child);
    },
    borderRadius: BorderRadius.circular(100.0),
    boxShadow: highModeShadow,
    closeButton: const ToastCloseButton(showType: CloseButtonShowType.none),
    dragToClose: true,
    borderSide: BorderSide(color: Colors.transparent),
  );
}

Future<Directory> getArcadiaDocuments(String? subDir) async {  
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(docs.path, 'Arcadia', subDir));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}
