class Role {
  final int? id;
  final int businessId;
  final int? branchId;
  final String name;
  final String? description;
  final bool status;
  final List<int> permissionIds;

  Role({
    this.id,
    required this.businessId,
    this.branchId,
    required this.name,
    this.description,
    this.status = true,
    this.permissionIds = const [],
  });

  factory Role.fromMap(Map<String, dynamic> map, {List<int> permissions = const []}) {
    return Role(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id']?.toString() ?? ''),
      businessId: map['business_id'] is int ? map['business_id'] : int.tryParse(map['business_id']?.toString() ?? '') ?? 0,
      branchId: map['branch_id'] is int ? map['branch_id'] : int.tryParse(map['branch_id']?.toString() ?? ''),
      name: map['name']?.toString() ?? 'Unknown',
      description: map['description']?.toString(),
      status: (map['status'] ?? 1) == 1,
      permissionIds: permissions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'branch_id': branchId,
      'name': name,
      'description': description,
      'status': status ? 1 : 0,
    };
  }
}
