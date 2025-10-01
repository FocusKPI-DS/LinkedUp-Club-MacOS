import 'package:ff_commons/flutter_flow/enums.dart';
export 'package:ff_commons/flutter_flow/enums.dart';

enum ParticipantStatus {
  joined,
  cancle,
  fail,
}

enum Interested {
  Business,
  Design,
  Technology,
  Finance,
  Health,
  Education,
  Arts,
  Science,
}

enum MessageType {
  text,
  file,
  image,
  voice,
}

enum Reports {
  Spam,
  Harassment,
  Inappropriate,
  etc,
}

enum PostType {
  Happy,
  Lost,
  Explore,
  Excited,
  Sad,
  CrashOut,
  Wonder,
}

T? deserializeEnum<T>(String? value) {
  switch (T) {
    case (ParticipantStatus):
      return ParticipantStatus.values.deserialize(value) as T?;
    case (Interested):
      return Interested.values.deserialize(value) as T?;
    case (MessageType):
      return MessageType.values.deserialize(value) as T?;
    case (Reports):
      return Reports.values.deserialize(value) as T?;
    case (PostType):
      return PostType.values.deserialize(value) as T?;
    default:
      return null;
  }
}
