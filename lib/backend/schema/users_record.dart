import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class UsersRecord extends FirestoreRecord {
  UsersRecord._(
    super.reference,
    super.data,
  ) {
    _initializeFields();
  }

  // "email" field.
  String? _email;
  String get email => _email ?? '';
  bool hasEmail() => _email != null;

  // "display_name" field.
  String? _displayName;
  String get displayName => _displayName ?? '';
  bool hasDisplayName() => _displayName != null;

  // "photo_url" field.
  String? _photoUrl;
  String get photoUrl => _photoUrl ?? '';
  bool hasPhotoUrl() => _photoUrl != null;

  // "uid" field.
  String? _uid;
  String get uid => _uid ?? '';
  bool hasUid() => _uid != null;

  // "created_time" field.
  DateTime? _createdTime;
  DateTime? get createdTime => _createdTime;
  bool hasCreatedTime() => _createdTime != null;

  // "phone_number" field.
  String? _phoneNumber;
  String get phoneNumber => _phoneNumber ?? '';
  bool hasPhoneNumber() => _phoneNumber != null;

  // "location" field.
  String? _location;
  String get location => _location ?? '';
  bool hasLocation() => _location != null;

  // "interests" field.
  List<String>? _interests;
  List<String> get interests => _interests ?? const [];
  bool hasInterests() => _interests != null;

  // "notifications_enabled" field.
  bool? _notificationsEnabled;
  bool get notificationsEnabled => _notificationsEnabled ?? false;
  bool hasNotificationsEnabled() => _notificationsEnabled != null;

  // "bio" field.
  String? _bio;
  String get bio => _bio ?? '';
  bool hasBio() => _bio != null;

  // "is_onboarding" field.
  bool? _isOnboarding;
  bool get isOnboarding => _isOnboarding ?? false;
  bool hasIsOnboarding() => _isOnboarding != null;

  // "new_message_enabled" field.
  bool? _newMessageEnabled;
  bool get newMessageEnabled => _newMessageEnabled ?? false;
  bool hasNewMessageEnabled() => _newMessageEnabled != null;

  // "connection_requests_enabled" field.
  bool? _connectionRequestsEnabled;
  bool get connectionRequestsEnabled => _connectionRequestsEnabled ?? false;
  bool hasConnectionRequestsEnabled() => _connectionRequestsEnabled != null;

  // "referrer_ref" field.
  DocumentReference? _referrerRef;
  DocumentReference? get referrerRef => _referrerRef;
  bool hasReferrerRef() => _referrerRef != null;

  // "location_latlng" field.
  LatLng? _locationLatlng;
  LatLng? get locationLatlng => _locationLatlng;
  bool hasLocationLatlng() => _locationLatlng != null;

  // "friends" field.
  List<DocumentReference>? _friends;
  List<DocumentReference> get friends => _friends ?? const [];
  bool hasFriends() => _friends != null;

  // "sent_requests" field.
  List<DocumentReference>? _sentRequests;
  List<DocumentReference> get sentRequests => _sentRequests ?? const [];
  bool hasSentRequests() => _sentRequests != null;

  // "friend_requests" field.
  List<DocumentReference>? _friendRequests;
  List<DocumentReference> get friendRequests => _friendRequests ?? const [];
  bool hasFriendRequests() => _friendRequests != null;

  // "is_online" field.
  bool? _isOnline;
  bool get isOnline => _isOnline ?? false;
  bool hasIsOnline() => _isOnline != null;

  // "agreed_to_terms" field.
  bool? _agreedToTerms;
  bool get agreedToTerms => _agreedToTerms ?? false;
  bool hasAgreedToTerms() => _agreedToTerms != null;

  // "invitation_code" field.
  String? _invitationCode;
  String get invitationCode => _invitationCode ?? '';
  bool hasInvitationCodeField() => _invitationCode != null;

  // "invited_by_code" field.
  String? _invitedByCode;
  String get invitedByCode => _invitedByCode ?? '';
  bool hasInvitedByCode() => _invitedByCode != null;

  // "invited_by" field.
  String? _invitedBy;
  String get invitedBy => _invitedBy ?? '';
  bool hasInvitedBy() => _invitedBy != null;

  // "save_posts" field.
  List<DocumentReference>? _savePosts;
  List<DocumentReference> get savePosts => _savePosts ?? const [];
  bool hasSavePosts() => _savePosts != null;

  // "eventbrite_connected" field.
  bool? _eventbriteConnected;
  bool get eventbriteConnected => _eventbriteConnected ?? false;
  bool hasEventbriteConnected() => _eventbriteConnected != null;

  // "eventbrite_access_token" field.
  String? _eventbriteAccessToken;
  String get eventbriteAccessToken => _eventbriteAccessToken ?? '';
  bool hasEventbriteAccessToken() => _eventbriteAccessToken != null;

  // "eventbrite_refresh_token" field.
  String? _eventbriteRefreshToken;
  String get eventbriteRefreshToken => _eventbriteRefreshToken ?? '';
  bool hasEventbriteRefreshToken() => _eventbriteRefreshToken != null;

  // "eventbrite_user_id" field.
  String? _eventbriteUserId;
  String get eventbriteUserId => _eventbriteUserId ?? '';
  bool hasEventbriteUserId() => _eventbriteUserId != null;

  // "eventbrite_user_name" field.
  String? _eventbriteUserName;
  String get eventbriteUserName => _eventbriteUserName ?? '';
  bool hasEventbriteUserName() => _eventbriteUserName != null;

  // "eventbrite_connected_at" field.
  DateTime? _eventbriteConnectedAt;
  DateTime? get eventbriteConnectedAt => _eventbriteConnectedAt;
  bool hasEventbriteConnectedAt() => _eventbriteConnectedAt != null;

  // "eventbrite_auto_sync" field.
  bool? _eventbriteAutoSync;
  bool get eventbriteAutoSync => _eventbriteAutoSync ?? false;
  bool hasEventbriteAutoSync() => _eventbriteAutoSync != null;

  // "eventbrite_last_sync" field.
  DateTime? _eventbriteLastSync;
  DateTime? get eventbriteLastSync => _eventbriteLastSync;
  bool hasEventbriteLastSync() => _eventbriteLastSync != null;

  // "has_invitation_code" field.
  bool? _hasInvitationCode;
  bool get hasInvitationCode => _hasInvitationCode ?? false;
  bool hasHasInvitationCode() => _hasInvitationCode != null;

  // "registration_type" field.
  String? _registrationType;
  String get registrationType => _registrationType ?? '';
  bool hasRegistrationType() => _registrationType != null;

  // "account_status" field.
  String? _accountStatus;
  String get accountStatus => _accountStatus ?? '';
  bool hasAccountStatus() => _accountStatus != null;

  // "current_workspace_ref" field.
  DocumentReference? _currentWorkspaceRef;
  DocumentReference? get currentWorkspaceRef => _currentWorkspaceRef;
  bool hasCurrentWorkspaceRef() => _currentWorkspaceRef != null;

  // "workspaces" field.
  List<DocumentReference>? _workspaces;
  List<DocumentReference> get workspaces => _workspaces ?? const [];
  bool hasWorkspaces() => _workspaces != null;

  // "default_workspace_ref" field.
  DocumentReference? _defaultWorkspaceRef;
  DocumentReference? get defaultWorkspaceRef => _defaultWorkspaceRef;
  bool hasDefaultWorkspaceRef() => _defaultWorkspaceRef != null;

  void _initializeFields() {
    _email = snapshotData['email'] as String?;
    _displayName = snapshotData['display_name'] as String?;
    _photoUrl = snapshotData['photo_url'] as String?;
    _uid = snapshotData['uid'] as String?;
    _createdTime = snapshotData['created_time'] as DateTime?;
    _phoneNumber = snapshotData['phone_number'] as String?;
    _location = snapshotData['location'] as String?;
    _interests = getDataList(snapshotData['interests']);
    _notificationsEnabled = snapshotData['notifications_enabled'] as bool?;
    _bio = snapshotData['bio'] as String?;
    _isOnboarding = snapshotData['is_onboarding'] as bool?;
    _newMessageEnabled = snapshotData['new_message_enabled'] as bool?;
    _connectionRequestsEnabled =
        snapshotData['connection_requests_enabled'] as bool?;
    _referrerRef = snapshotData['referrer_ref'] as DocumentReference?;
    _locationLatlng = snapshotData['location_latlng'] as LatLng?;
    _friends = getDataList(snapshotData['friends']);
    _sentRequests = getDataList(snapshotData['sent_requests']);
    _friendRequests = getDataList(snapshotData['friend_requests']);
    _isOnline = snapshotData['is_online'] as bool?;
    _agreedToTerms = snapshotData['agreed_to_terms'] as bool?;
    _invitationCode = snapshotData['invitation_code'] as String?;
    _invitedByCode = snapshotData['invited_by_code'] as String?;
    _invitedBy = snapshotData['invited_by'] as String?;
    _savePosts = getDataList(snapshotData['save_posts']);
    _eventbriteConnected = snapshotData['eventbrite_connected'] as bool?;
    _eventbriteAccessToken = snapshotData['eventbrite_access_token'] as String?;
    _eventbriteRefreshToken =
        snapshotData['eventbrite_refresh_token'] as String?;
    _eventbriteUserId = snapshotData['eventbrite_user_id'] as String?;
    _eventbriteUserName = snapshotData['eventbrite_user_name'] as String?;
    _eventbriteConnectedAt =
        snapshotData['eventbrite_connected_at'] as DateTime?;
    _eventbriteAutoSync = snapshotData['eventbrite_auto_sync'] as bool?;
    _eventbriteLastSync = snapshotData['eventbrite_last_sync'] as DateTime?;
    _hasInvitationCode = snapshotData['has_invitation_code'] as bool?;
    _registrationType = snapshotData['registration_type'] as String?;
    _accountStatus = snapshotData['account_status'] as String?;
    _currentWorkspaceRef =
        snapshotData['current_workspace_ref'] as DocumentReference?;
    _workspaces = getDataList(snapshotData['workspaces']);
    _defaultWorkspaceRef =
        snapshotData['default_workspace_ref'] as DocumentReference?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('users');

  static Stream<UsersRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => UsersRecord.fromSnapshot(s));

  static Future<UsersRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => UsersRecord.fromSnapshot(s));

  static UsersRecord fromSnapshot(DocumentSnapshot snapshot) => UsersRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static UsersRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      UsersRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'UsersRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is UsersRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createUsersRecordData({
  String? email,
  String? displayName,
  String? photoUrl,
  String? uid,
  DateTime? createdTime,
  String? phoneNumber,
  String? location,
  bool? notificationsEnabled,
  String? bio,
  bool? isOnboarding,
  bool? newMessageEnabled,
  bool? connectionRequestsEnabled,
  DocumentReference? referrerRef,
  LatLng? locationLatlng,
  bool? isOnline,
  bool? agreedToTerms,
  String? invitationCode,
  String? invitedByCode,
  String? invitedBy,
  bool? eventbriteConnected,
  String? eventbriteAccessToken,
  String? eventbriteRefreshToken,
  String? eventbriteUserId,
  String? eventbriteUserName,
  DateTime? eventbriteConnectedAt,
  bool? eventbriteAutoSync,
  DateTime? eventbriteLastSync,
  bool? hasInvitationCode,
  String? registrationType,
  String? accountStatus,
  DocumentReference? currentWorkspaceRef,
  DocumentReference? defaultWorkspaceRef,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'email': email,
      'display_name': displayName,
      'photo_url': photoUrl,
      'uid': uid,
      'created_time': createdTime,
      'phone_number': phoneNumber,
      'location': location,
      'notifications_enabled': notificationsEnabled,
      'bio': bio,
      'is_onboarding': isOnboarding,
      'new_message_enabled': newMessageEnabled,
      'connection_requests_enabled': connectionRequestsEnabled,
      'referrer_ref': referrerRef,
      'location_latlng': locationLatlng,
      'is_online': isOnline,
      'agreed_to_terms': agreedToTerms,
      'invitation_code': invitationCode,
      'invited_by_code': invitedByCode,
      'invited_by': invitedBy,
      'eventbrite_connected': eventbriteConnected,
      'eventbrite_access_token': eventbriteAccessToken,
      'eventbrite_refresh_token': eventbriteRefreshToken,
      'eventbrite_user_id': eventbriteUserId,
      'eventbrite_user_name': eventbriteUserName,
      'eventbrite_connected_at': eventbriteConnectedAt,
      'eventbrite_auto_sync': eventbriteAutoSync,
      'eventbrite_last_sync': eventbriteLastSync,
      'has_invitation_code': hasInvitationCode,
      'registration_type': registrationType,
      'account_status': accountStatus,
      'current_workspace_ref': currentWorkspaceRef,
      'default_workspace_ref': defaultWorkspaceRef,
    }.withoutNulls,
  );

  return firestoreData;
}

class UsersRecordDocumentEquality implements Equality<UsersRecord> {
  const UsersRecordDocumentEquality();

  @override
  bool equals(UsersRecord? e1, UsersRecord? e2) {
    const listEquality = ListEquality();
    return e1?.email == e2?.email &&
        e1?.displayName == e2?.displayName &&
        e1?.photoUrl == e2?.photoUrl &&
        e1?.uid == e2?.uid &&
        e1?.createdTime == e2?.createdTime &&
        e1?.phoneNumber == e2?.phoneNumber &&
        e1?.location == e2?.location &&
        listEquality.equals(e1?.interests, e2?.interests) &&
        e1?.notificationsEnabled == e2?.notificationsEnabled &&
        e1?.bio == e2?.bio &&
        e1?.isOnboarding == e2?.isOnboarding &&
        e1?.newMessageEnabled == e2?.newMessageEnabled &&
        e1?.connectionRequestsEnabled == e2?.connectionRequestsEnabled &&
        e1?.referrerRef == e2?.referrerRef &&
        e1?.locationLatlng == e2?.locationLatlng &&
        listEquality.equals(e1?.friends, e2?.friends) &&
        listEquality.equals(e1?.sentRequests, e2?.sentRequests) &&
        listEquality.equals(e1?.friendRequests, e2?.friendRequests) &&
        e1?.isOnline == e2?.isOnline &&
        e1?.agreedToTerms == e2?.agreedToTerms &&
        e1?.invitationCode == e2?.invitationCode &&
        e1?.invitedByCode == e2?.invitedByCode &&
        e1?.invitedBy == e2?.invitedBy &&
        listEquality.equals(e1?.savePosts, e2?.savePosts) &&
        e1?.eventbriteConnected == e2?.eventbriteConnected &&
        e1?.eventbriteAccessToken == e2?.eventbriteAccessToken &&
        e1?.eventbriteRefreshToken == e2?.eventbriteRefreshToken &&
        e1?.eventbriteUserId == e2?.eventbriteUserId &&
        e1?.eventbriteUserName == e2?.eventbriteUserName &&
        e1?.eventbriteConnectedAt == e2?.eventbriteConnectedAt &&
        e1?.eventbriteAutoSync == e2?.eventbriteAutoSync &&
        e1?.eventbriteLastSync == e2?.eventbriteLastSync &&
        e1?.hasInvitationCode == e2?.hasInvitationCode &&
        e1?.registrationType == e2?.registrationType &&
        e1?.accountStatus == e2?.accountStatus &&
        e1?.currentWorkspaceRef == e2?.currentWorkspaceRef &&
        listEquality.equals(e1?.workspaces, e2?.workspaces) &&
        e1?.defaultWorkspaceRef == e2?.defaultWorkspaceRef;
  }

  @override
  int hash(UsersRecord? e) => const ListEquality().hash([
        e?.email,
        e?.displayName,
        e?.photoUrl,
        e?.uid,
        e?.createdTime,
        e?.phoneNumber,
        e?.location,
        e?.interests,
        e?.notificationsEnabled,
        e?.bio,
        e?.isOnboarding,
        e?.newMessageEnabled,
        e?.connectionRequestsEnabled,
        e?.referrerRef,
        e?.locationLatlng,
        e?.friends,
        e?.sentRequests,
        e?.friendRequests,
        e?.isOnline,
        e?.agreedToTerms,
        e?.invitationCode,
        e?.invitedByCode,
        e?.invitedBy,
        e?.savePosts,
        e?.eventbriteConnected,
        e?.eventbriteAccessToken,
        e?.eventbriteRefreshToken,
        e?.eventbriteUserId,
        e?.eventbriteUserName,
        e?.eventbriteConnectedAt,
        e?.eventbriteAutoSync,
        e?.eventbriteLastSync,
        e?.hasInvitationCode,
        e?.registrationType,
        e?.accountStatus,
        e?.currentWorkspaceRef,
        e?.workspaces,
        e?.defaultWorkspaceRef
      ]);

  @override
  bool isValidKey(Object? o) => o is UsersRecord;
}
