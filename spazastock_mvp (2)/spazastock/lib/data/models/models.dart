// lib/data/models/product_model.dart
import 'package:uuid/uuid.dart';

class Product {
  final String id;
  final String name;
  final String nameSetswana;
  final String? sku;
  final String category;
  final double price;
  final double costPrice;
  int quantity;
  final int lowStockThreshold;
  final String? expiryDate;
  String? nfcTagId;
  final String? imagePath;
  final bool isActive;
  final bool synced;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    String? id,
    required this.name,
    this.nameSetswana = '',
    this.sku,
    this.category = 'General',
    required this.price,
    this.costPrice = 0.0,
    this.quantity = 0,
    this.lowStockThreshold = 5,
    this.expiryDate,
    this.nfcTagId,
    this.imagePath,
    this.isActive = true,
    this.synced = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isLowStock => quantity <= lowStockThreshold;
  bool get isOutOfStock => quantity <= 0;
  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    final expiry = DateTime.tryParse(expiryDate!);
    if (expiry == null) return false;
    return expiry.isBefore(DateTime.now().add(const Duration(days: 7)));
  }

  double get margin =>
      costPrice > 0 ? ((price - costPrice) / price) * 100 : 0;

  Product copyWith({
    String? name,
    String? nameSetswana,
    String? sku,
    String? category,
    double? price,
    double? costPrice,
    int? quantity,
    int? lowStockThreshold,
    String? expiryDate,
    String? nfcTagId,
    String? imagePath,
    bool? isActive,
    bool? synced,
  }) =>
      Product(
        id: id,
        name: name ?? this.name,
        nameSetswana: nameSetswana ?? this.nameSetswana,
        sku: sku ?? this.sku,
        category: category ?? this.category,
        price: price ?? this.price,
        costPrice: costPrice ?? this.costPrice,
        quantity: quantity ?? this.quantity,
        lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
        expiryDate: expiryDate ?? this.expiryDate,
        nfcTagId: nfcTagId ?? this.nfcTagId,
        imagePath: imagePath ?? this.imagePath,
        isActive: isActive ?? this.isActive,
        synced: synced ?? this.synced,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'name_setswana': nameSetswana,
        'sku': sku,
        'category': category,
        'price': price,
        'cost_price': costPrice,
        'quantity': quantity,
        'low_stock_threshold': lowStockThreshold,
        'expiry_date': expiryDate,
        'nfc_tag_id': nfcTagId,
        'image_path': imagePath,
        'is_active': isActive ? 1 : 0,
        'synced': synced ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: map['id'] as String,
        name: map['name'] as String,
        nameSetswana: (map['name_setswana'] as String?) ?? '',
        sku: map['sku'] as String?,
        category: (map['category'] as String?) ?? 'General',
        price: (map['price'] as num).toDouble(),
        costPrice: (map['cost_price'] as num).toDouble(),
        quantity: map['quantity'] as int,
        lowStockThreshold: (map['low_stock_threshold'] as int?) ?? 5,
        expiryDate: map['expiry_date'] as String?,
        nfcTagId: map['nfc_tag_id'] as String?,
        imagePath: map['image_path'] as String?,
        isActive: (map['is_active'] as int) == 1,
        synced: (map['synced'] as int) == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  @override
  String toString() => 'Product(id: $id, name: $name, qty: $quantity)';
}

// ── NfcTag ──────────────────────────────────────────────────────────────────

class NfcTag {
  final String id;
  final String tagUid;
  String? productId;
  final DateTime writtenAt;
  final bool isActive;

  NfcTag({
    String? id,
    required this.tagUid,
    this.productId,
    DateTime? writtenAt,
    this.isActive = true,
  })  : id = id ?? const Uuid().v4(),
        writtenAt = writtenAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'tag_uid': tagUid,
        'product_id': productId,
        'written_at': writtenAt.toIso8601String(),
        'is_active': isActive ? 1 : 0,
      };

  factory NfcTag.fromMap(Map<String, dynamic> map) => NfcTag(
        id: map['id'] as String,
        tagUid: map['tag_uid'] as String,
        productId: map['product_id'] as String?,
        writtenAt: DateTime.parse(map['written_at'] as String),
        isActive: (map['is_active'] as int) == 1,
      );
}

// ── Sale ────────────────────────────────────────────────────────────────────

enum PaymentMethod { cash, orangeMoney, myZaka, card, other }

class Sale {
  final String id;
  final String productId;
  final String productName;
  final int quantitySold;
  final double unitPrice;
  final double totalAmount;
  final PaymentMethod paymentMethod;
  final String? paymentRef;
  final bool synced;
  final DateTime soldAt;

  Sale({
    String? id,
    required this.productId,
    required this.productName,
    this.quantitySold = 1,
    required this.unitPrice,
    required this.totalAmount,
    this.paymentMethod = PaymentMethod.cash,
    this.paymentRef,
    this.synced = false,
    DateTime? soldAt,
  })  : id = id ?? const Uuid().v4(),
        soldAt = soldAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'product_id': productId,
        'product_name': productName,
        'quantity_sold': quantitySold,
        'unit_price': unitPrice,
        'total_amount': totalAmount,
        'payment_method': paymentMethod.name,
        'payment_ref': paymentRef,
        'synced': synced ? 1 : 0,
        'sold_at': soldAt.toIso8601String(),
      };

  factory Sale.fromMap(Map<String, dynamic> map) => Sale(
        id: map['id'] as String,
        productId: map['product_id'] as String,
        productName: map['product_name'] as String,
        quantitySold: map['quantity_sold'] as int,
        unitPrice: (map['unit_price'] as num).toDouble(),
        totalAmount: (map['total_amount'] as num).toDouble(),
        paymentMethod: PaymentMethod.values.byName(
          (map['payment_method'] as String?) ?? 'cash',
        ),
        paymentRef: map['payment_ref'] as String?,
        synced: (map['synced'] as int) == 1,
        soldAt: DateTime.parse(map['sold_at'] as String),
      );
}

// ── StockMovement ───────────────────────────────────────────────────────────

enum MovementType { purchase, sale, adjustment, waste, nfcSale }

class StockMovement {
  final String id;
  final String productId;
  final MovementType movementType;
  final int quantityDelta;
  final String reason;
  final String? referenceId;
  final bool synced;
  final DateTime movedAt;

  StockMovement({
    String? id,
    required this.productId,
    required this.movementType,
    required this.quantityDelta,
    this.reason = '',
    this.referenceId,
    this.synced = false,
    DateTime? movedAt,
  })  : id = id ?? const Uuid().v4(),
        movedAt = movedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'product_id': productId,
        'movement_type': movementType.name,
        'quantity_delta': quantityDelta,
        'reason': reason,
        'reference_id': referenceId,
        'synced': synced ? 1 : 0,
        'moved_at': movedAt.toIso8601String(),
      };

  factory StockMovement.fromMap(Map<String, dynamic> map) => StockMovement(
        id: map['id'] as String,
        productId: map['product_id'] as String,
        movementType: MovementType.values.byName(
          (map['movement_type'] as String?) ?? 'adjustment',
        ),
        quantityDelta: map['quantity_delta'] as int,
        reason: (map['reason'] as String?) ?? '',
        referenceId: map['reference_id'] as String?,
        synced: (map['synced'] as int) == 1,
        movedAt: DateTime.parse(map['moved_at'] as String),
      );
}

// ── SyncQueue ───────────────────────────────────────────────────────────────

enum SyncOperation { create, update, delete }
enum SyncStatus { pending, inProgress, failed, completed }

class SyncQueueItem {
  final String id;
  final String entityType;
  final String entityId;
  final SyncOperation operation;
  final String payloadJson;
  int retryCount;
  SyncStatus status;
  final DateTime queuedAt;
  DateTime? lastAttempt;

  SyncQueueItem({
    String? id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payloadJson,
    this.retryCount = 0,
    this.status = SyncStatus.pending,
    DateTime? queuedAt,
    this.lastAttempt,
  })  : id = id ?? const Uuid().v4(),
        queuedAt = queuedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'entity_type': entityType,
        'entity_id': entityId,
        'operation': operation.name,
        'payload_json': payloadJson,
        'retry_count': retryCount,
        'status': status.name,
        'queued_at': queuedAt.toIso8601String(),
        'last_attempt': lastAttempt?.toIso8601String(),
      };

  factory SyncQueueItem.fromMap(Map<String, dynamic> map) => SyncQueueItem(
        id: map['id'] as String,
        entityType: map['entity_type'] as String,
        entityId: map['entity_id'] as String,
        operation: SyncOperation.values.byName(
          (map['operation'] as String?) ?? 'create',
        ),
        payloadJson: map['payload_json'] as String,
        retryCount: (map['retry_count'] as int?) ?? 0,
        status: SyncStatus.values.byName(
          (map['status'] as String?) ?? 'pending',
        ),
        queuedAt: DateTime.parse(map['queued_at'] as String),
        lastAttempt: map['last_attempt'] != null
            ? DateTime.parse(map['last_attempt'] as String)
            : null,
      );
}
