import 'dart:convert';

class EstimateItem {
  final String itemName;
  final String categoryName;
  final String metalType; // 22K Gold, 18K Gold, Silver, Platinum
  final double grossWeight;
  final double stoneWeight;
  final double netWeight;
  final double ratePerGram;
  final double wastagePercent;
  final double makingCharges;
  final double stoneCharges;
  final double totalAmount;

  EstimateItem({
    required this.itemName,
    this.categoryName = '',
    this.metalType = '22K Gold',
    required this.grossWeight,
    this.stoneWeight = 0.0,
    required this.netWeight,
    required this.ratePerGram,
    this.wastagePercent = 0.0,
    this.makingCharges = 0.0,
    this.stoneCharges = 0.0,
    required this.totalAmount,
  });

  factory EstimateItem.fromJson(Map<String, dynamic> json) {
    return EstimateItem(
      itemName: json['item_name']?.toString() ?? '',
      categoryName: json['category_name']?.toString() ?? '',
      metalType: json['metal_type']?.toString() ?? '22K Gold',
      grossWeight: (json['gross_weight'] as num?)?.toDouble() ?? 0.0,
      stoneWeight: (json['stone_weight'] as num?)?.toDouble() ?? 0.0,
      netWeight: (json['net_weight'] as num?)?.toDouble() ?? 0.0,
      ratePerGram: (json['rate_per_gram'] as num?)?.toDouble() ?? 0.0,
      wastagePercent: (json['wastage_percent'] as num?)?.toDouble() ?? 0.0,
      makingCharges: (json['making_charges'] as num?)?.toDouble() ?? 0.0,
      stoneCharges: (json['stone_charges'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_name': itemName,
      'category_name': categoryName,
      'metal_type': metalType,
      'gross_weight': grossWeight,
      'stone_weight': stoneWeight,
      'net_weight': netWeight,
      'rate_per_gram': ratePerGram,
      'wastage_percent': wastagePercent,
      'making_charges': makingCharges,
      'stone_charges': stoneCharges,
      'total_amount': totalAmount,
    };
  }
}

class EstimateRecord {
  final int? estimateId;
  final String estimateNo;
  final String customerName;
  final String customerMobile;
  final String customerAddress;
  final double grossWeight;
  final double netWeight;
  final double totalMetalValue;
  final double totalMakingCharges;
  final double totalStoneCharges;
  final double taxableAmount;
  final double taxAmount;
  final double netAmount;
  final int validDays;
  final String status; // 'OPEN', 'CONVERTED', 'EXPIRED'
  final List<EstimateItem> items;
  final String notes;
  final String? createdAt;
  final String? updatedAt;

  EstimateRecord({
    this.estimateId,
    required this.estimateNo,
    required this.customerName,
    this.customerMobile = '',
    this.customerAddress = '',
    this.grossWeight = 0.0,
    this.netWeight = 0.0,
    this.totalMetalValue = 0.0,
    this.totalMakingCharges = 0.0,
    this.totalStoneCharges = 0.0,
    this.taxableAmount = 0.0,
    this.taxAmount = 0.0,
    this.netAmount = 0.0,
    this.validDays = 7,
    this.status = 'OPEN',
    this.items = const [],
    this.notes = '',
    this.createdAt,
    this.updatedAt,
  });

  factory EstimateRecord.fromJson(Map<String, dynamic> json) {
    List<EstimateItem> parsedItems = [];
    final rawItems = json['items_json'];
    if (rawItems is List) {
      parsedItems = rawItems.map((e) => EstimateItem.fromJson(e as Map<String, dynamic>)).toList();
    } else if (rawItems is String && rawItems.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawItems);
        if (decoded is List) {
          parsedItems = decoded.map((e) => EstimateItem.fromJson(e as Map<String, dynamic>)).toList();
        }
      } catch (_) {
        parsedItems = [];
      }
    }

    return EstimateRecord(
      estimateId: json['estimate_id'] != null ? int.tryParse(json['estimate_id'].toString()) : null,
      estimateNo: json['estimate_no']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? '',
      customerMobile: json['customer_mobile']?.toString() ?? '',
      customerAddress: json['customer_address']?.toString() ?? '',
      grossWeight: (json['gross_weight'] as num?)?.toDouble() ?? 0.0,
      netWeight: (json['net_weight'] as num?)?.toDouble() ?? 0.0,
      totalMetalValue: (json['total_metal_value'] as num?)?.toDouble() ?? 0.0,
      totalMakingCharges: (json['total_making_charges'] as num?)?.toDouble() ?? 0.0,
      totalStoneCharges: (json['total_stone_charges'] as num?)?.toDouble() ?? 0.0,
      taxableAmount: (json['taxable_amount'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0.0,
      netAmount: (json['net_amount'] as num?)?.toDouble() ?? 0.0,
      validDays: int.tryParse(json['valid_days']?.toString() ?? '7') ?? 7,
      status: json['status']?.toString().toUpperCase() ?? 'OPEN',
      items: parsedItems,
      notes: json['notes']?.toString() ?? '',
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (estimateId != null) 'estimate_id': estimateId,
      'estimate_no': estimateNo,
      'customer_name': customerName,
      'customer_mobile': customerMobile,
      'customer_address': customerAddress,
      'gross_weight': grossWeight,
      'net_weight': netWeight,
      'total_metal_value': totalMetalValue,
      'total_making_charges': totalMakingCharges,
      'total_stone_charges': totalStoneCharges,
      'taxable_amount': taxableAmount,
      'tax_amount': taxAmount,
      'net_amount': netAmount,
      'valid_days': validDays,
      'status': status,
      'items_json': jsonEncode(items.map((i) => i.toJson()).toList()),
      'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }
}
