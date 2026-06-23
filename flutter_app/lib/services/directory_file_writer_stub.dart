import 'dart:typed_data';

class DirectoryFileWriter {
  const DirectoryFileWriter();

  Future<String?> writeBytesToDirectory({
    required String directoryPath,
    required String fileName,
    required Uint8List bytes,
  }) async {
    return null;
  }
}

DirectoryFileWriter createDirectoryFileWriter() {
  return const DirectoryFileWriter();
}

