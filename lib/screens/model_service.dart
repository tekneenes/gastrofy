//import 'dart:typed_data';
//import 'package:flutter/services.dart';
//import 'package:tflite_flutter/tflite_flutter.dart';
//
//class ModelService {
//  // Singleton pattern
//  static final ModelService _instance = ModelService._internal();
//  factory ModelService() => _instance;
//  ModelService._internal();
//
//  Interpreter? _interpreter;
//  Uint8List? _tokenizerBytes;
//
//  // Model ve tokenizer yükleme
//  Future<void> loadModel() async {
//    try {
//      // TFLite modelini yükle
//      _interpreter = await Interpreter.fromAsset(
//        'assets/embeddinggemma-300M_seq1024_mixed-precision.tflite',
//      );
//
//      // Tokenizer dosyasını yükle
//      final tokenizerData = await rootBundle.load('assets/sentencepiece.model');
//      _tokenizerBytes = tokenizerData.buffer.asUint8List();
//
//      print('Model ve tokenizer yüklendi.');
//    } catch (e) {
//      print('Model yüklenirken hata oluştu: $e');
//    }
//  }
//
//  // Model interpreter getter
//  Interpreter get interpreter {
//    if (_interpreter == null) {
//      throw Exception('Interpreter yüklenmedi. loadModel() çağrılmalı.');
//    }
//    return _interpreter!;
//  }
//
//  // Tokenizer verisi getter
//  Uint8List get tokenizer {
//    if (_tokenizerBytes == null) {
//      throw Exception('Tokenizer yüklenmedi. loadModel() çağrılmalı.');
//    }
//    return _tokenizerBytes!;
//  }
//
//  // Örnek: Metin embedding veya özetleme için input/output işleme
//  // Buraya kendi input tensor hazırlama ve output işlemlerini ekleyebilirsin
//}
//
