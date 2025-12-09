import 'package:open_file/open_file.dart';

class FileHandlerService {
  static final FileHandlerService _instance = FileHandlerService._internal();

  factory FileHandlerService() {
    return _instance;
  }

  FileHandlerService._internal();

  /// Dosya yolunu alır ve açar
  void openFile(String filePath) {
    if (filePath.isNotEmpty) {
      print('Opening file: $filePath');
      OpenFile.open(filePath);
    }
  }
}
