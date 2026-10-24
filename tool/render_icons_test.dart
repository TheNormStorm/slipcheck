// Renders the legacy (pre-Android 8) launcher PNGs from the logo painter:
//   flutter test tool/render_icons_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slipcheck/ui/components/brand.dart';

void main() {
  test('render launcher icons', () async {
    const sizes = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192};
    for (final MapEntry(key: density, value: px) in sizes.entries) {
      final recorder = ui.PictureRecorder();
      LogoPainter().paint(Canvas(recorder), Size.square(px.toDouble()));
      final image = await recorder.endRecording().toImage(px, px);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('android/app/src/main/res/mipmap-$density/ic_launcher.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    }
  });
}
