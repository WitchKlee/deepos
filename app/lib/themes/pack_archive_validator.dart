/// Bounded ZIP, strict UTF-8 JSON and PNG integrity helpers for local theme packs.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'pack_name_alias.dart';

part 'pack_archive.dart';
part 'pack_json.dart';
part 'pack_png.dart';

const petJsonCap = 262144;
const petSheetByteCap = 8388608;
const petSheetSideCap = 4096;
const petSheetDecodedCap = 16777216;
const petArchiveByteCap = 67108864;
const petArchiveExpandedCap = 67108864;
const petArchiveEntryCap = 256;
const petJsonDepthCap = 64;
const petPngMetadataChunkCap = 1048576;
const petPngMetadataTotalCap = 67108864;

class PetValidationException implements Exception {
  const PetValidationException(this.code, [this.path]);
  final String code;
  final String? path;

  @override
  String toString() => 'PetValidationException($code${path == null ? '' : ': $path'})';
}

void _require(bool condition, String code, [String? path]) {
  if (!condition) throw PetValidationException(code, path);
}
