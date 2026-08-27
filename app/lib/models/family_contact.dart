/// Model representing a saved family member contact for trip notifications.
class FamilyContact {
  final String id;
  final String name;
  final String phone;
  final String channel; // 'whatsapp' | 'sms'

  const FamilyContact({
    required this.id,
    required this.name,
    required this.phone,
    this.channel = 'whatsapp',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'channel': channel,
      };

  factory FamilyContact.fromJson(Map<String, dynamic> json) => FamilyContact(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        channel: json['channel'] as String? ?? 'whatsapp',
      );
}
