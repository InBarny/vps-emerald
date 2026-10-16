// lib/vpn/services/singbox_binary_service.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/errors/vpn_error.dart';

class SingBoxBinaryDescriptor {
  const SingBoxBinaryDescriptor({
    required this.binaryAssetPath,
    required this.binaryExecutableName,
    this.requiredCompanionFile,
  });

  final String binaryAssetPath;
  final String binaryExecutableName;
  final String? requiredCompanionFile;
}

class SingBoxBinaryService {
  static const String _versionFileName = 'singbox.version';

  SingBoxBinaryDescriptor resolveForCurrentPlatform() {
    return const SingBoxBinaryDescriptor(
      binaryAssetPath: 'assets/binaries/windows/',
      binaryExecutableName: 'sing-box.exe',
      requiredCompanionFile: 'wintun.dll',
    );
  }

  /// Возвращает путь к постоянной директории для хранения бинарников.
  Future<String> _getBinaryStorageDir() async {
    final appSupport = await getApplicationSupportDirectory();
    final dir = Directory('${appSupport.path}/binaries');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  /// Вычисляет SHA256 хеш файла из ассетов (для проверки версии).
  Future<String> _computeAssetHash(String assetPath) async {
    final ByteData data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    return sha256.convert(bytes).toString();
  }

  Future<SingBoxRuntimeFiles> prepareRuntimeBinaryFromAssets({
    required SingBoxBinaryDescriptor descriptor,
  }) async {
    final storageDir = await _getBinaryStorageDir();
    final String binaryPath =
        '$storageDir${Platform.pathSeparator}${descriptor.binaryExecutableName}';
    final File binaryFile = File(binaryPath);
    final String versionFilePath =
        '$storageDir${Platform.pathSeparator}$_versionFileName';

    // Вычисляем текущий хеш бинарника из ассетов
    final String assetHash = await _computeAssetHash(
      '${descriptor.binaryAssetPath}${descriptor.binaryExecutableName}',
    );

    // Проверяем, нужно ли обновлять файл
    bool needUpdate = true;
    if (await binaryFile.exists()) {
      final versionFile = File(versionFilePath);
      if (await versionFile.exists()) {
        final storedHash = await versionFile.readAsString();
        if (storedHash.trim() == assetHash) {
          needUpdate = false;
        }
      }
    }

    if (needUpdate) {
      // Копируем бинарник из ассетов
      await _writeAssetToFile(
        assetPath:
            '${descriptor.binaryAssetPath}${descriptor.binaryExecutableName}',
        destination: binaryFile,
      );
      // Сохраняем хеш
      await File(versionFilePath).writeAsString(assetHash);
    }

    String? companionPath;
    if (descriptor.requiredCompanionFile != null) {
      companionPath =
          '$storageDir${Platform.pathSeparator}${descriptor.requiredCompanionFile!}';
      final File companionFile = File(companionPath);
      if (!await companionFile.exists() || needUpdate) {
        await _writeAssetToFile(
          assetPath:
              '${descriptor.binaryAssetPath}${descriptor.requiredCompanionFile!}',
          destination: companionFile,
        );
      }
    }



    return SingBoxRuntimeFiles(
      binaryPath: binaryPath,
      companionFilePath: companionPath,
    );
  }

  Future<void> _writeAssetToFile({
    required String assetPath,
    required File destination,
  }) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      await destination.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    } catch (e) {
      // Если не удалось загрузить из ассетов, пробуем скопировать из файловой системы (для разработки)
      final File source = File(assetPath);
      if (await source.exists()) {
        await source.copy(destination.path);
      } else {
        throw VpnError(
          VpnErrorKind.binaryNotFound,
          'Asset and fallback file not found at $assetPath\nError: $e',
        );
      }
    }
  }
}

class SingBoxRuntimeFiles {
  const SingBoxRuntimeFiles({required this.binaryPath, this.companionFilePath});

  final String binaryPath;
  final String? companionFilePath;
}
