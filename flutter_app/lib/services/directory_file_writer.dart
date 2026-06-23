import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'directory_file_writer_stub.dart'
    if (dart.library.io) 'directory_file_writer_io.dart';

export 'directory_file_writer_stub.dart'
    if (dart.library.io) 'directory_file_writer_io.dart';

final directoryFileWriterProvider = Provider<DirectoryFileWriter>((ref) {
  return createDirectoryFileWriter();
});
