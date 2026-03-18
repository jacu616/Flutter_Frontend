// lib/home/notifications/notify.dart

class AppNotification {
  final int                    id;
  final int                    actorId;
  final String                 actorName;
  final String?                actorAvatar;
  final String                 verb;
  final String?                targetType;
  final int?                   targetId;
  final Map<String, dynamic>?  targetDetails;
  final bool                   read;
  final DateTime               timestamp;
  final String                 timeAgo;

  const AppNotification({
    required this.id,
    required this.actorId,
    required this.actorName,
    this.actorAvatar,
    required this.verb,
    this.targetType,
    this.targetId,
    this.targetDetails,
    required this.read,
    required this.timestamp,
    required this.timeAgo,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id:            json['id']           as int,
      actorId:       json['actor_id']     as int,
      actorName:     json['actor_name']   as String,
      actorAvatar:   json['actor_avatar'] as String?,
      verb:          json['verb']         as String,
      targetType:    json['target_type']  as String?,
      targetId:      json['target_id']    as int?,
      targetDetails: (json['target_details'] as Map?)?.cast<String, dynamic>(),
      read:          json['read']         as bool,
      timestamp:     DateTime.parse(json['timestamp'] as String),
      timeAgo:       json['time_ago']     as String,
    );
  }
}