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
}
