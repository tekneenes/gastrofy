import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'database_helper.dart';
import '../models/order_model.dart';
import '../models/order_item_model.dart';

class LocalSyncService {
  HttpServer? _server;
  final _dbHelper = DatabaseHelper.instance;
  final _info = NetworkInfo();

  // Singleton pattern
  LocalSyncService._privateConstructor();
  static final LocalSyncService instance = LocalSyncService._privateConstructor();

  /// Sunucuyu (Kasa/Yönetici cihazı) başlatır.
  Future<String?> startServer() async {
    if (_server != null) return await _info.getWifiIP();

    final router = Router();

    // Endpoints
    router.get('/sync/status', _handleStatus);
    router.get('/sync/data', _handleGetAllData);
    router.post('/sync/update_order', _handleUpdateOrder);
    router.post('/sync/clear_table', _handleClearTable);

    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(router);

  try {
      String? ip = await _info.getWifiIP();
      
      // Fallback: getWifiIP null dönerse (örn. kablolu ağ veya izin sorunları)
      if (ip == null || ip.isEmpty) {
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLoopback: false,
        );
        if (interfaces.isNotEmpty) {
          // Genellikle ilk interface (en0, eth0 gibi) ana ağ arayüzüdür
          for (var interface in interfaces) {
            for (var addr in interface.addresses) {
              if (addr.address.startsWith('192.') || 
                  addr.address.startsWith('10.') || 
                  addr.address.startsWith('172.')) {
                ip = addr.address;
                break;
              }
            }
            if (ip != null) break;
          }
          // Hala null ise ilkini al
          ip ??= interfaces.first.addresses.first.address;
        }
      }

      if (ip == null) return null;

      _server = await io.serve(handler, ip, 8080);
      debugPrint('Sync Sunucusu Başlatıldı: http://$ip:8080');
      return ip;
    } catch (e) {
      debugPrint('Sunucu başlatma hatası: $e');
      return null;
    }
  }

  Future<void> stopServer() async {
    await _server?.close(force: true);
    _server = null;
  }

  // --- Handlers ---

  Response _handleStatus(Request request) {
    return Response.ok(jsonEncode({
      'status': 'online',
      'device': 'Server',
      'timestamp': DateTime.now().toIso8601String(),
    }), headers: {'content-type': 'application/json'});
  }

  Future<Response> _handleGetAllData(Request request) async {
    try {
      final tables = await _dbHelper.getTables();
      final sections = await _dbHelper.getSections();
      // Basitleştirilmiş veri paketi
      final data = {
        'tables': tables,
        'sections': sections,
      };
      return Response.ok(jsonEncode(data), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: e.toString());
    }
  }

  Future<Response> _handleUpdateOrder(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      
      // data: { tableId: string, items: List<Map>, user: Map }
      final String tableId = data['tableId'];
      final List itemsData = data['items'];
      final Map<String, dynamic> user = Map<String, dynamic>.from(data['user'] ?? {});

      // Bu noktada TableProvider.addOrderToTable'a benzer bir mantık gerekiyor.
      // Ancak doğrudan DB'ye yazıp TableProvider'ı uyarmak daha kolay.
      final activeOrder = await _dbHelper.getActiveOrderByTableId(tableId);
      int orderId;
      
      if (activeOrder == null) {
        final newOrder = OrderModel(tableId: tableId, createdAt: DateTime.now());
        final createdOrder = await _dbHelper.insertMainOrder(newOrder);
        orderId = createdOrder.id!;
      } else {
        orderId = activeOrder.id!;
      }

      for (var item in itemsData) {
        final orderItem = OrderItem(
          orderId: orderId,
          productId: item['productId'],
          productName: item['productName'],
          productPrice: (item['productPrice'] as num).toDouble(),
          quantity: item['quantity'],
          isSpecialProduct: item['isSpecialProduct'] == 1,
        );
        await _dbHelper.insertOrderItem(orderItem);
      }

      // Log ekle
      await _dbHelper.insertLog(
        userName: user['userName'] ?? 'Garson',
        actionType: 'Ürün Ekle (Sync)',
        details: 'Masa $tableId - ${itemsData.length} kalem ürün eklendi.',
      );

      return Response.ok(jsonEncode({'success': true}));
    } catch (e) {
      return Response.internalServerError(body: e.toString());
    }
  }

  Future<Response> _handleClearTable(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final String tableId = data['tableId'];
      final Map<String, dynamic> user = Map<String, dynamic>.from(data['user'] ?? {});

      await _dbHelper.clearTable(tableId);

      await _dbHelper.insertLog(
        userName: user['userName'] ?? 'Garson',
        actionType: 'Masa Kapat (Sync)',
        details: 'Masa $tableId kapatıldı / temizlendi.',
      );

      return Response.ok(jsonEncode({'success': true}));
    } catch (e) {
      return Response.internalServerError(body: e.toString());
    }
  }

  Future<Response> _handleMoveTable(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final String fromId = data['fromId'];
      final String toId = data['toId'];
      final Map<String, dynamic> user = Map<String, dynamic>.from(data['user'] ?? {});

      await _dbHelper.moveTable(fromId, toId);

      await _dbHelper.insertLog(
        userName: user['userName'] ?? 'Garson',
        actionType: 'Masa Taşı (Sync)',
        details: '$fromId -> $toId masasına taşındı.',
      );

      return Response.ok(jsonEncode({'success': true}));
    } catch (e) {
      return Response.internalServerError(body: e.toString());
    }
  }

  // --- Client Side Methods (Waiter) ---

  Future<Map<String, dynamic>?> fetchFromServer(String serverIp) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse('http://$serverIp:8080/sync/data'));
      final response = await request.close();
      if (response.statusCode == 200) {
        final content = await response.transform(utf8.decoder).join();
        return jsonDecode(content);
      }
    } catch (e) {
      debugPrint('Sunucudan veri çekme hatası: $e');
    } finally {
      client.close();
    }
    return null;
  }

  Future<bool> sendUpdateOrder(String serverIp, String tableId, List items, Map user) async {
    return await _postToServer(serverIp, '/sync/update_order', {
      'tableId': tableId,
      'items': items,
      'user': user,
    });
  }

  Future<bool> sendClearTable(String serverIp, String tableId, Map user) async {
    return await _postToServer(serverIp, '/sync/clear_table', {
      'tableId': tableId,
      'user': user,
    });
  }

  Future<bool> sendMoveTable(String serverIp, String fromId, String toId, Map user) async {
    return await _postToServer(serverIp, '/sync/move_table', {
      'fromId': fromId,
      'toId': toId,
      'user': user,
    });
  }

  Future<bool> _postToServer(String serverIp, String path, Map data) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse('http://$serverIp:8080$path'));
      request.headers.set('content-type', 'application/json');
      request.write(jsonEncode(data));
      final response = await request.close();
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Sunucuya veri gönderme hatası: $e');
      return false;
    } finally {
      client.close();
    }
  }
}
