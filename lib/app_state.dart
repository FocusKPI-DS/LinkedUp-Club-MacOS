import 'package:flutter/material.dart';
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FFAppState extends ChangeNotifier {
  static FFAppState _instance = FFAppState._internal();

  factory FFAppState() {
    return _instance;
  }

  FFAppState._internal();

  static void reset() {
    _instance = FFAppState._internal();
  }

  Future initializePersistedState() async {
    prefs = await SharedPreferences.getInstance();
    _safeInit(() {
      _Category = prefs.getStringList('ff_Category') ?? _Category;
    });
    _safeInit(() {
      _IsEnterInvitationCode =
          prefs.getBool('ff_IsEnterInvitationCode') ?? _IsEnterInvitationCode;
    });
    _safeInit(() {
      _history = prefs.getStringList('ff_history') ?? _history;
    });
    _safeInit(() {
      _chatSearch = prefs.getStringList('ff_chatSearch') ?? _chatSearch;
    });
    _safeInit(() {
      _ABC = prefs.getStringList('ff_ABC') ?? _ABC;
    });
    _safeInit(() {
      _searchUsersHistory =
          prefs.getStringList('ff_searchUsersHistory') ?? _searchUsersHistory;
    });
    _safeInit(() {
      final lastOpenedString = prefs.getString('ff_newsPageLastOpened');
      _newsPageLastOpened =
          lastOpenedString != null ? DateTime.parse(lastOpenedString) : null;
    });
    _safeInit(() {
      final lastOpenedString = prefs.getString('ff_chatPageLastOpened');
      _chatPageLastOpened =
          lastOpenedString != null ? DateTime.parse(lastOpenedString) : null;
    });
  }

  void update(VoidCallback callback) {
    callback();
    notifyListeners();
  }

  late SharedPreferences prefs;

  List<String> _Category = [
    'Business',
    'Design',
    'Technology',
    'Finance',
    'Health',
    'Education',
    'Arts',
    'Science'
  ];
  List<String> get Category => _Category;
  set Category(List<String> value) {
    _Category = value;
    prefs.setStringList('ff_Category', value);
  }

  void addToCategory(String value) {
    Category.add(value);
    prefs.setStringList('ff_Category', _Category);
  }

  void removeFromCategory(String value) {
    Category.remove(value);
    prefs.setStringList('ff_Category', _Category);
  }

  void removeAtIndexFromCategory(int index) {
    Category.removeAt(index);
    prefs.setStringList('ff_Category', _Category);
  }

  void updateCategoryAtIndex(
    int index,
    String Function(String) updateFn,
  ) {
    Category[index] = updateFn(_Category[index]);
    prefs.setStringList('ff_Category', _Category);
  }

  void insertAtIndexInCategory(int index, String value) {
    Category.insert(index, value);
    prefs.setStringList('ff_Category', _Category);
  }

  bool _IsEnterInvitationCode = false;
  bool get IsEnterInvitationCode => _IsEnterInvitationCode;
  set IsEnterInvitationCode(bool value) {
    _IsEnterInvitationCode = value;
    prefs.setBool('ff_IsEnterInvitationCode', value);
  }

  List<String> _history = [];
  List<String> get history => _history;
  set history(List<String> value) {
    _history = value;
    prefs.setStringList('ff_history', value);
  }

  void addToHistory(String value) {
    history.add(value);
    prefs.setStringList('ff_history', _history);
  }

  void removeFromHistory(String value) {
    history.remove(value);
    prefs.setStringList('ff_history', _history);
  }

  void removeAtIndexFromHistory(int index) {
    history.removeAt(index);
    prefs.setStringList('ff_history', _history);
  }

  void updateHistoryAtIndex(
    int index,
    String Function(String) updateFn,
  ) {
    history[index] = updateFn(_history[index]);
    prefs.setStringList('ff_history', _history);
  }

  void insertAtIndexInHistory(int index, String value) {
    history.insert(index, value);
    prefs.setStringList('ff_history', _history);
  }

  List<DateScheduleStruct> _scheduleDate = [];
  List<DateScheduleStruct> get scheduleDate => _scheduleDate;
  set scheduleDate(List<DateScheduleStruct> value) {
    _scheduleDate = value;
  }

  void addToScheduleDate(DateScheduleStruct value) {
    scheduleDate.add(value);
  }

  void removeFromScheduleDate(DateScheduleStruct value) {
    scheduleDate.remove(value);
  }

  void removeAtIndexFromScheduleDate(int index) {
    scheduleDate.removeAt(index);
  }

  void updateScheduleDateAtIndex(
    int index,
    DateScheduleStruct Function(DateScheduleStruct) updateFn,
  ) {
    scheduleDate[index] = updateFn(_scheduleDate[index]);
  }

  void insertAtIndexInScheduleDate(int index, DateScheduleStruct value) {
    scheduleDate.insert(index, value);
  }

  String _pathAudio = '';
  String get pathAudio => _pathAudio;
  set pathAudio(String value) {
    _pathAudio = value;
  }

  List<String> _chatSearch = [];
  List<String> get chatSearch => _chatSearch;
  set chatSearch(List<String> value) {
    _chatSearch = value;
    prefs.setStringList('ff_chatSearch', value);
  }

  void addToChatSearch(String value) {
    chatSearch.add(value);
    prefs.setStringList('ff_chatSearch', _chatSearch);
  }

  void removeFromChatSearch(String value) {
    chatSearch.remove(value);
    prefs.setStringList('ff_chatSearch', _chatSearch);
  }

  void removeAtIndexFromChatSearch(int index) {
    chatSearch.removeAt(index);
    prefs.setStringList('ff_chatSearch', _chatSearch);
  }

  void updateChatSearchAtIndex(
    int index,
    String Function(String) updateFn,
  ) {
    chatSearch[index] = updateFn(_chatSearch[index]);
    prefs.setStringList('ff_chatSearch', _chatSearch);
  }

  void insertAtIndexInChatSearch(int index, String value) {
    chatSearch.insert(index, value);
    prefs.setStringList('ff_chatSearch', _chatSearch);
  }

  List<String> _ABC = [
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z'
  ];
  List<String> get ABC => _ABC;
  set ABC(List<String> value) {
    _ABC = value;
    prefs.setStringList('ff_ABC', value);
  }

  void addToABC(String value) {
    ABC.add(value);
    prefs.setStringList('ff_ABC', _ABC);
  }

  void removeFromABC(String value) {
    ABC.remove(value);
    prefs.setStringList('ff_ABC', _ABC);
  }

  void removeAtIndexFromABC(int index) {
    ABC.removeAt(index);
    prefs.setStringList('ff_ABC', _ABC);
  }

  void updateABCAtIndex(
    int index,
    String Function(String) updateFn,
  ) {
    ABC[index] = updateFn(_ABC[index]);
    prefs.setStringList('ff_ABC', _ABC);
  }

  void insertAtIndexInABC(int index, String value) {
    ABC.insert(index, value);
    prefs.setStringList('ff_ABC', _ABC);
  }

  List<String> _searchUsersHistory = [];
  List<String> get searchUsersHistory => _searchUsersHistory;
  set searchUsersHistory(List<String> value) {
    _searchUsersHistory = value;
    prefs.setStringList('ff_searchUsersHistory', value);
  }

  void addToSearchUsersHistory(String value) {
    searchUsersHistory.add(value);
    prefs.setStringList('ff_searchUsersHistory', _searchUsersHistory);
  }

  void removeFromSearchUsersHistory(String value) {
    searchUsersHistory.remove(value);
    prefs.setStringList('ff_searchUsersHistory', _searchUsersHistory);
  }

  void removeAtIndexFromSearchUsersHistory(int index) {
    searchUsersHistory.removeAt(index);
    prefs.setStringList('ff_searchUsersHistory', _searchUsersHistory);
  }

  void updateSearchUsersHistoryAtIndex(
    int index,
    String Function(String) updateFn,
  ) {
    searchUsersHistory[index] = updateFn(_searchUsersHistory[index]);
    prefs.setStringList('ff_searchUsersHistory', _searchUsersHistory);
  }

  void insertAtIndexInSearchUsersHistory(int index, String value) {
    searchUsersHistory.insert(index, value);
    prefs.setStringList('ff_searchUsersHistory', _searchUsersHistory);
  }

  int _invitedCode = 0;
  int get invitedCode => _invitedCode;
  set invitedCode(int value) {
    _invitedCode = value;
  }

  String _eventId = '';
  String get eventId => _eventId;
  set eventId(String value) {
    _eventId = value;
  }

  String _userRef = '';
  String get userRef => _userRef;
  set userRef(String value) {
    _userRef = value;
  }

  String _linkUrl = '';
  String get linkUrl => _linkUrl;
  set linkUrl(String value) {
    _linkUrl = value;
  }

  DeeplinkInfoStruct _DeeplinkInfo = DeeplinkInfoStruct();
  DeeplinkInfoStruct get DeeplinkInfo => _DeeplinkInfo;
  set DeeplinkInfo(DeeplinkInfoStruct value) {
    _DeeplinkInfo = value;
  }

  void updateDeeplinkInfoStruct(Function(DeeplinkInfoStruct) updateFn) {
    updateFn(_DeeplinkInfo);
  }

  bool _skippedInvitation = false;
  bool get skippedInvitation => _skippedInvitation;
  set skippedInvitation(bool value) {
    _skippedInvitation = value;
  }

  // Transient flag to show the News alert only once per app run
  bool _hasShownNewsAlert = false;
  bool get hasShownNewsAlert => _hasShownNewsAlert;
  set hasShownNewsAlert(bool value) {
    _hasShownNewsAlert = value;
  }

  // Track when News page was last opened to show unread indicator
  DateTime? _newsPageLastOpened;
  DateTime? get newsPageLastOpened => _newsPageLastOpened;
  set newsPageLastOpened(DateTime? value) {
    _newsPageLastOpened = value;
    if (value != null) {
      prefs.setString('ff_newsPageLastOpened', value.toIso8601String());
    } else {
      prefs.remove('ff_newsPageLastOpened');
    }
  }

  // Track when Chat page was last opened to show unread indicator
  DateTime? _chatPageLastOpened;
  DateTime? get chatPageLastOpened => _chatPageLastOpened;
  set chatPageLastOpened(DateTime? value) {
    _chatPageLastOpened = value;
    if (value != null) {
      prefs.setString('ff_chatPageLastOpened', value.toIso8601String());
    } else {
      prefs.remove('ff_chatPageLastOpened');
    }
  }
}

void _safeInit(Function() initializeField) {
  try {
    initializeField();
  } catch (_) {}
}

Future _safeInitAsync(Function() initializeField) async {
  try {
    await initializeField();
  } catch (_) {}
}
