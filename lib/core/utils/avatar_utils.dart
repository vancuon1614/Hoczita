import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

ImageProvider? resolveAvatarImage(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('data:image/') ||
      path.startsWith('blob:') ||
      path.startsWith('http://') ||
      path.startsWith('https://') ||
      kIsWeb) {
    return NetworkImage(path);
  }
  return FileImage(File(path));
}
