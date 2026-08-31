class Metal {
  final String metalid;
  final String metalname;
  final String? createdAt;
  final String? updatedAt;

  Metal({
    required this.metalid,
    required this.metalname,
    this.createdAt,
    this.updatedAt,
  });

  factory Metal.fromJson(Map<String, dynamic> json) {
    return Metal(
      metalid: json['metalid']?.toString() ?? '',
      metalname: json['metalname']?.toString() ?? '',
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'metalid': metalid,
      'metalname': metalname,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }
}

class Purity {
  final int? purityid;
  final String metalid;
  final String purityname;
  final String purityshortname;
  final double purity;
  final String type; // 'ORNAMENT' or 'METAL'
  final String? metalname;
  final String? createdAt;
  final String? updatedAt;

  Purity({
    this.purityid,
    required this.metalid,
    required this.purityname,
    required this.purityshortname,
    required this.purity,
    required this.type,
    this.metalname,
    this.createdAt,
    this.updatedAt,
  });

  factory Purity.fromJson(Map<String, dynamic> json) {
    return Purity(
      purityid: json['purityid'] != null ? int.tryParse(json['purityid'].toString()) : null,
      metalid: json['metalid']?.toString() ?? '',
      purityname: json['purityname']?.toString() ?? '',
      purityshortname: json['purityshortname']?.toString() ?? '',
      purity: json['purity'] != null ? double.tryParse(json['purity'].toString()) ?? 0.0 : 0.0,
      type: json['type']?.toString() ?? 'ORNAMENT',
      metalname: json['metalname']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (purityid != null) 'purityid': purityid,
      'metalid': metalid,
      'purityname': purityname,
      'purityshortname': purityshortname,
      'purity': purity,
      'type': type,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }
}

class CategoryRecord {
  final int? id;
  final String metalid;
  final String catcode;
  final String catname;
  final String categorytype; // 'METAL' or 'ORNAMENTS/STONE'
  final double sgstPer;
  final double cgstPer;
  final double igstPer;
  final String sgstacname;
  final String cgstacname;
  final String igstacname;
  final String? metalname;
  final String? createdAt;
  final String? updatedAt;

  CategoryRecord({
    this.id,
    required this.metalid,
    required this.catcode,
    required this.catname,
    required this.categorytype,
    this.sgstPer = 0.0,
    this.cgstPer = 0.0,
    this.igstPer = 0.0,
    this.sgstacname = '',
    this.cgstacname = '',
    this.igstacname = '',
    this.metalname,
    this.createdAt,
    this.updatedAt,
  });

  factory CategoryRecord.fromJson(Map<String, dynamic> json) {
    return CategoryRecord(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      metalid: json['metalid']?.toString() ?? '',
      catcode: json['catcode']?.toString() ?? '',
      catname: json['catname']?.toString() ?? '',
      categorytype: json['categorytype']?.toString() ?? 'ORNAMENTS/STONE',
      sgstPer: json['sgst_per'] != null ? double.tryParse(json['sgst_per'].toString()) ?? 0.0 : 0.0,
      cgstPer: json['cgst_per'] != null ? double.tryParse(json['cgst_per'].toString()) ?? 0.0 : 0.0,
      igstPer: json['igst_per'] != null ? double.tryParse(json['igst_per'].toString()) ?? 0.0 : 0.0,
      sgstacname: json['sgstacname']?.toString() ?? '',
      cgstacname: json['cgstacname']?.toString() ?? '',
      igstacname: json['igstacname']?.toString() ?? '',
      metalname: json['metalname']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'metalid': metalid,
      'catcode': catcode,
      'catname': catname,
      'categorytype': categorytype,
      'sgst_per': sgstPer,
      'cgst_per': cgstPer,
      'igst_per': igstPer,
      'sgstacname': sgstacname,
      'cgstacname': cgstacname,
      'igstacname': igstacname,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  CategoryRecord copyWith({
    int? id,
    String? metalid,
    String? catcode,
    String? catname,
    String? categorytype,
    double? sgstPer,
    double? cgstPer,
    double? igstPer,
    String? sgstacname,
    String? cgstacname,
    String? igstacname,
    String? metalname,
    String? createdAt,
    String? updatedAt,
  }) {
    return CategoryRecord(
      id: id ?? this.id,
      metalid: metalid ?? this.metalid,
      catcode: catcode ?? this.catcode,
      catname: catname ?? this.catname,
      categorytype: categorytype ?? this.categorytype,
      sgstPer: sgstPer ?? this.sgstPer,
      cgstPer: cgstPer ?? this.cgstPer,
      igstPer: igstPer ?? this.igstPer,
      sgstacname: sgstacname ?? this.sgstacname,
      cgstacname: cgstacname ?? this.cgstacname,
      igstacname: igstacname ?? this.igstacname,
      metalname: metalname ?? this.metalname,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ProductRecord {
  final int? productid;
  final int categoryid;
  final String productname;
  final String calctype; // 'WEIGHT', 'RATE', 'METAL', 'FIXED'
  final String stocktype; // 'SKU', 'OPEN'
  final String havestoneDiamond; // 'YES', 'NO'
  final String havesubproduct; // 'YES', 'NO'
  final String? catname;
  final String? catcode;
  final String? categorytype;
  final String? metalid;
  final String? metalname;
  final String? createdAt;
  final String? updatedAt;

  ProductRecord({
    this.productid,
    required this.categoryid,
    required this.productname,
    this.calctype = 'WEIGHT',
    this.stocktype = 'SKU',
    this.havestoneDiamond = 'NO',
    this.havesubproduct = 'NO',
    this.catname,
    this.catcode,
    this.categorytype,
    this.metalid,
    this.metalname,
    this.createdAt,
    this.updatedAt,
  });

  factory ProductRecord.fromJson(Map<String, dynamic> json) {
    return ProductRecord(
      productid: json['productid'] != null ? int.tryParse(json['productid'].toString()) : null,
      categoryid: int.tryParse(json['categoryid']?.toString() ?? '0') ?? 0,
      productname: json['productname']?.toString() ?? '',
      calctype: json['calctype']?.toString() ?? 'WEIGHT',
      stocktype: json['stocktype']?.toString() ?? 'SKU',
      havestoneDiamond: json['havestone_diamond']?.toString() ?? 'NO',
      havesubproduct: json['havesubproduct']?.toString() ?? 'NO',
      catname: json['catname']?.toString(),
      catcode: json['catcode']?.toString(),
      categorytype: json['categorytype']?.toString(),
      metalid: json['metalid']?.toString(),
      metalname: json['metalname']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (productid != null) 'productid': productid,
      'categoryid': categoryid,
      'productname': productname,
      'calctype': calctype,
      'stocktype': stocktype,
      'havestone_diamond': havestoneDiamond,
      'havesubproduct': havesubproduct,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  ProductRecord copyWith({
    int? productid,
    int? categoryid,
    String? productname,
    String? calctype,
    String? stocktype,
    String? havestoneDiamond,
    String? havesubproduct,
    String? catname,
    String? catcode,
    String? categorytype,
    String? metalid,
    String? metalname,
    String? createdAt,
    String? updatedAt,
  }) {
    return ProductRecord(
      productid: productid ?? this.productid,
      categoryid: categoryid ?? this.categoryid,
      productname: productname ?? this.productname,
      calctype: calctype ?? this.calctype,
      stocktype: stocktype ?? this.stocktype,
      havestoneDiamond: havestoneDiamond ?? this.havestoneDiamond,
      havesubproduct: havesubproduct ?? this.havesubproduct,
      catname: catname ?? this.catname,
      catcode: catcode ?? this.catcode,
      categorytype: categorytype ?? this.categorytype,
      metalid: metalid ?? this.metalid,
      metalname: metalname ?? this.metalname,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class SubProductRecord {
  final int? subproductid;
  final int productid;
  final String subproductname;
  final String havestoneDiamond; // 'YES', 'NO'
  final String? productname;
  final String? catname;
  final String? catcode;
  final String? metalname;
  final String? metalid;
  final String? createdAt;
  final String? updatedAt;

  SubProductRecord({
    this.subproductid,
    required this.productid,
    required this.subproductname,
    this.havestoneDiamond = 'NO',
    this.productname,
    this.catname,
    this.catcode,
    this.metalname,
    this.metalid,
    this.createdAt,
    this.updatedAt,
  });

  factory SubProductRecord.fromJson(Map<String, dynamic> json) {
    return SubProductRecord(
      subproductid: json['subproductid'] != null ? int.tryParse(json['subproductid'].toString()) : null,
      productid: int.tryParse(json['productid']?.toString() ?? '0') ?? 0,
      subproductname: json['subproductname']?.toString() ?? '',
      havestoneDiamond: json['havestone_diamond']?.toString() ?? 'NO',
      productname: json['productname']?.toString(),
      catname: json['catname']?.toString(),
      catcode: json['catcode']?.toString(),
      metalname: json['metalname']?.toString(),
      metalid: json['metalid']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (subproductid != null) 'subproductid': subproductid,
      'productid': productid,
      'subproductname': subproductname,
      'havestone_diamond': havestoneDiamond,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  SubProductRecord copyWith({
    int? subproductid,
    int? productid,
    String? subproductname,
    String? havestoneDiamond,
    String? productname,
    String? catname,
    String? catcode,
    String? metalname,
    String? metalid,
    String? createdAt,
    String? updatedAt,
  }) {
    return SubProductRecord(
      subproductid: subproductid ?? this.subproductid,
      productid: productid ?? this.productid,
      subproductname: subproductname ?? this.subproductname,
      havestoneDiamond: havestoneDiamond ?? this.havestoneDiamond,
      productname: productname ?? this.productname,
      catname: catname ?? this.catname,
      catcode: catcode ?? this.catcode,
      metalname: metalname ?? this.metalname,
      metalid: metalid ?? this.metalid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
