class AccountModel {
  final int? id;
  final String name;
  final int? pinOrder;

  AccountModel({this.id, required this.name, this.pinOrder});

  bool get isPinned => pinOrder != null;

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'pinOrder': pinOrder};
  }

  factory AccountModel.fromMap(Map<String, dynamic> map) {
    return AccountModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      pinOrder: map['pinOrder'] as int?,
    );
  }
}
