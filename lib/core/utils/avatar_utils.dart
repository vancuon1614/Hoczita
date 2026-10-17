import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

ImageProvider? resolveAvatarImage(String? path) {
  if (path == null || path.trim().isEmpty) return null;
  var cleanPath = path.trim();

  // Data URI or base64 image
  if (cleanPath.startsWith('data:image/') ||
      (cleanPath.startsWith('data:') && cleanPath.contains('base64,'))) {
    try {
      final commaIndex = cleanPath.indexOf(',');
      final base64Str =
          commaIndex != -1 ? cleanPath.substring(commaIndex + 1) : cleanPath;
      return MemoryImage(base64Decode(base64Str.trim()));
    } catch (_) {
      return null;
    }
  }

  // Network URL
  if (cleanPath.startsWith('http://') ||
      cleanPath.startsWith('https://') ||
      cleanPath.startsWith('blob:')) {
    cleanPath = cleanPath.replaceAll(RegExp(r'(?<!:)//+'), '/');
    return NetworkImage(cleanPath);
  }

  // Web platform
  if (kIsWeb) {
    cleanPath = cleanPath.replaceAll(RegExp(r'(?<!:)//+'), '/');
    return NetworkImage(cleanPath);
  }

  // Local file
  try {
    final file = File(path);
    if (file.existsSync()) {
      return FileImage(file);
    }
  } catch (_) {}

  // Fallback for raw base64 string
  if (path.length > 200 && !path.contains('/') && !path.contains('\\')) {
    try {
      return MemoryImage(base64Decode(path.trim()));
    } catch (_) {}
  }

  return null;
}
