import 'package:uuid/uuid.dart';
import 'dart:convert'; // jsonDecode için gerekli

// --- Sipariş Ürün Kalemi Modeli (OrderItemModel) ---
// BU KISIMDA DEĞİŞİKLİK YOK
/// Sipariş edilen ürün detaylarını tutan model.
class OrderItemModel {
  final String id;
  final String productId; // Sipariş edilen ürünün ID'si
  final String productName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  OrderItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id'] as String? ?? const Uuid().v4(),
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      quantity: json['quantity'] as int,
      unitPrice: (json['unitPrice'] as num).toDouble(),
      totalPrice: (json['totalPrice'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
    };
  }

  factory OrderItemModel.fromSqliteMap(Map<String, dynamic> map) {
    return OrderItemModel(
      id: map['productId'] as String,
      productId: map['productId'] as String,
      productName: map['productName'] as String,
      quantity: map['quantity'] as int,
      unitPrice: (map['productPrice'] as num).toDouble(),
      totalPrice:
          (map['productPrice'] as num).toDouble() * (map['quantity'] as int),
    );
  }
}

// --- Masa Kayıt Durumları (Enum) ---
// BU KISIMDA DEĞİŞİKLİK YOK
enum TableRecordStatus { open, waitingForPayment, closed }

extension TableRecordStatusExtension on TableRecordStatus {
  String toShortString() {
    return toString().split('.').last;
  }
}

// --- Masa Kaydı Ana Modeli (TableRecordModel) ---
// --- DEĞİŞİKLİKLER BU SINIF İÇİNDE YAPILDI ---
class TableRecordModel {
  final String id;
  final String tableId;
  final String tableName; // YENİ: Masa adını tutacak alan eklendi.
  final DateTime startTime;
  final int? durationInSeconds;
  final List<OrderItemModel> items;
  final double totalPrice;
  final TableRecordStatus status;
  final String? note;

  TableRecordModel({
    required this.id,
    required this.tableId,
    required this.tableName, // YENİ: Constructor'a eklendi.
    required this.startTime,
    this.durationInSeconds,
    required this.items,
    required this.totalPrice,
    this.status = TableRecordStatus.open,
    this.note,
  });

  Duration get duration => Duration(seconds: durationInSeconds ?? 0);

  factory TableRecordModel.fromJson(Map<String, dynamic> json) {
    final List<dynamic> itemsJson = json['items'] as List<dynamic>? ?? [];
    final items = itemsJson
        .map((itemJson) =>
            OrderItemModel.fromJson(itemJson as Map<String, dynamic>))
        .toList();
    return TableRecordModel(
      id: json['id'] as String,
      tableId: json['tableId'] as String,
      tableName: json['tableName'] as String? ??
          json['tableId']
              as String, // YENİ: JSON'dan okuma (geriye dönük uyumlu)
      startTime: DateTime.parse(json['startTime'] as String),
      durationInSeconds: json['durationInSeconds'] as int?,
      items: items,
      totalPrice: (json['totalPrice'] as num).toDouble(),
      status: TableRecordStatus.values.firstWhere(
        (e) =>
            e.toShortString() ==
            (json['status'] as String? ??
                TableRecordStatus.closed.toShortString()),
        orElse: () => TableRecordStatus.closed,
      ),
      note: json['note'] as String?,
    );
  }

  factory TableRecordModel.fromSqliteMap(Map<String, dynamic> map) {
    final List<dynamic> itemsList = jsonDecode(map['itemsJson'] as String);
    final items = itemsList
        .map((itemMap) =>
            OrderItemModel.fromSqliteMap(itemMap as Map<String, dynamic>))
        .toList();
    final int duration = map['durationSeconds'] as int? ?? 0;
    return TableRecordModel(
      id: (map['id'] as int).toString(),
      tableId: map['tableId'] as String,
      tableName: map['tableName']
          as String, // YENİ: Veritabanından gelen tableName okunuyor.
      startTime: DateTime.parse(map['startTime'] as String),
      durationInSeconds: duration,
      items: items,
      totalPrice: (map['total'] as num).toDouble(),
      status: TableRecordStatus.closed,
      note: map['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tableId': tableId,
      'tableName': tableName, // YENİ: JSON'a yazma
      'startTime': startTime.toIso8601String(),
      'durationInSeconds': durationInSeconds,
      'items': items.map((item) => item.toJson()).toList(),
      'totalPrice': totalPrice,
      'status': status.toShortString(),
      'note': note,
    };
  }

  TableRecordModel copyWith({
    String? id,
    String? tableId,
    String? tableName, // YENİ
    DateTime? startTime,
    int? durationInSeconds,
    List<OrderItemModel>? items,
    double? totalPrice,
    TableRecordStatus? status,
    String? note,
  }) {
    return TableRecordModel(
      id: id ?? this.id,
      tableId: tableId ?? this.tableId,
      tableName: tableName ?? this.tableName, // YENİ
      startTime: startTime ?? this.startTime,
      durationInSeconds: durationInSeconds ?? this.durationInSeconds,
      items: items ?? this.items,
      totalPrice: totalPrice ?? this.totalPrice,
      status: status ?? this.status,
      note: note ?? this.note,
    );
  }
}
