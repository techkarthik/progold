class AccountHead {
  final int? id;
  final String accode;
  final String groupname;
  final String accountname;
  final String state;
  final String country;
  final String pincode;
  final int active; // 1 = active, 0 = inactive
  final String gstno;
  final String panno;
  final String? createdAt;
  final String? updatedAt;

  AccountHead({
    this.id,
    required this.accode,
    required this.groupname,
    required this.accountname,
    this.state = '',
    this.country = 'India',
    this.pincode = '',
    this.active = 1,
    this.gstno = '',
    this.panno = '',
    this.createdAt,
    this.updatedAt,
  });

  factory AccountHead.fromJson(Map<String, dynamic> json) {
    return AccountHead(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      accode: json['accode']?.toString() ?? '',
      groupname: json['groupname']?.toString() ?? '',
      accountname: json['accountname']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      country: json['country']?.toString() ?? 'India',
      pincode: json['pincode']?.toString() ?? '',
      active: json['active'] != null ? int.tryParse(json['active'].toString()) ?? 1 : 1,
      gstno: json['gstno']?.toString() ?? '',
      panno: json['panno']?.toString() ?? '',
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'accode': accode,
      'groupname': groupname,
      'accountname': accountname,
      'state': state,
      'country': country,
      'pincode': pincode,
      'active': active,
      'gstno': gstno,
      'panno': panno,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  AccountHead copyWith({
    int? id,
    String? accode,
    String? groupname,
    String? accountname,
    String? state,
    String? country,
    String? pincode,
    int? active,
    String? gstno,
    String? panno,
    String? createdAt,
    String? updatedAt,
  }) {
    return AccountHead(
      id: id ?? this.id,
      accode: accode ?? this.accode,
      groupname: groupname ?? this.groupname,
      accountname: accountname ?? this.accountname,
      state: state ?? this.state,
      country: country ?? this.country,
      pincode: pincode ?? this.pincode,
      active: active ?? this.active,
      gstno: gstno ?? this.gstno,
      panno: panno ?? this.panno,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
