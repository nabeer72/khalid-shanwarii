class Role {
  final String id;
  final String businessId;
  final String? branchId;
  final String name;
  final String? description;
  final bool status;
  final List<String> permissionIds;

  Role({
    required this.id,
    required this.businessId,
    this.branchId,
    required this.name,
    this.description,
    this.status = true,
    this.permissionIds = const [],
  });

  factory Role.fromMap(Map<String, dynamic> map, {List<String> permissions = const []}) {
    return Role(
      id: map['id']?.toString() ?? '',
      businessId: map['business_id']?.toString() ?? '',
      branchId: map['branch_id']?.toString(),
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
