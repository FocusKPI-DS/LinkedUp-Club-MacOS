import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';

import '/auth/base_auth_user_provider.dart';

import '/backend/push_notifications/push_notifications_handler.dart'
    show PushNotificationsHandler;
import '/main.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:ff_commons/flutter_flow/lat_lng.dart';
import 'package:ff_commons/flutter_flow/place.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'serialization_util.dart';

import '/index.dart';
import 'package:branchio_dynamic_linking_akp5u6/index.dart'
    as $branchio_dynamic_linking_akp5u6;

export 'package:go_router/go_router.dart';
export 'serialization_util.dart';

const kTransitionInfoKey = '__transition_info__';

GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class AppStateNotifier extends ChangeNotifier {
  AppStateNotifier._();

  static AppStateNotifier? _instance;
  static AppStateNotifier get instance => _instance ??= AppStateNotifier._();

  BaseAuthUser? initialUser;
  BaseAuthUser? user;
  bool showSplashImage = true;
  String? _redirectLocation;

  /// Determines whether the app will refresh and build again when a sign
  /// in or sign out happens. This is useful when the app is launched or
  /// on an unexpected logout. However, this must be turned off when we
  /// intend to sign in/out and then navigate or perform any actions after.
  /// Otherwise, this will trigger a refresh and interrupt the action(s).
  bool notifyOnAuthChange = true;

  bool get loading => user == null || showSplashImage;
  bool get loggedIn => user?.loggedIn ?? false;
  bool get initiallyLoggedIn => initialUser?.loggedIn ?? false;
  bool get shouldRedirect => loggedIn && _redirectLocation != null;

  String getRedirectLocation() => _redirectLocation!;
  bool hasRedirect() => _redirectLocation != null;
  void setRedirectLocationIfUnset(String loc) => _redirectLocation ??= loc;
  void clearRedirectLocation() => _redirectLocation = null;

  /// Mark as not needing to notify on a sign in / out when we intend
  /// to perform subsequent actions (such as navigation) afterwards.
  void updateNotifyOnAuthChange(bool notify) => notifyOnAuthChange = notify;

  void update(BaseAuthUser newUser) {
    final shouldUpdate =
        user?.uid == null || newUser.uid == null || user?.uid != newUser.uid;
    initialUser ??= newUser;
    user = newUser;
    // Refresh the app on auth change unless explicitly marked otherwise.
    // No need to update unless the user has changed.
    if (notifyOnAuthChange && shouldUpdate) {
      notifyListeners();
    }
    // Once again mark the notifier as needing to update on auth change
    // (in order to catch sign in / out events).
    updateNotifyOnAuthChange(true);
  }

  void stopShowingSplashImage() {
    showSplashImage = false;
    notifyListeners();
  }
}

GoRouter createRouter(AppStateNotifier appStateNotifier) {
  $branchio_dynamic_linking_akp5u6.initializeRoutes(
    testHomePageWidgetName: 'branchio_dynamic_linking_akp5u6.TestHomePage',
    testHomePageWidgetPath: '/Discover',
    testDashboardWidgetName: 'branchio_dynamic_linking_akp5u6.TestDashboard',
    testDashboardWidgetPath: '/dashboard',
  );

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    refreshListenable: appStateNotifier,
    navigatorKey: appNavigatorKey,
    errorBuilder: (context, state) =>
        appStateNotifier.loggedIn ? NavBarPage() : const WelcomeWidget(),
    routes: [
      FFRoute(
        name: '_initialize',
        path: '/',
        builder: (context, _) =>
            appStateNotifier.loggedIn ? NavBarPage() : const WelcomeWidget(),
      ),
      FFRoute(
        name: LoginWidget.routeName,
        path: LoginWidget.routePath,
        builder: (context, params) => LoginWidget(
          isInvitation: params.getParam(
            'isInvitation',
            ParamType.bool,
          ),
        ),
      ),
      FFRoute(
        name: SignUpWidget.routeName,
        path: SignUpWidget.routePath,
        builder: (context, params) => SignUpWidget(
          isDeeplink: params.getParam(
            'isDeeplink',
            ParamType.bool,
          ),
          skippedInvite: params.getParam(
            'skippedInvite',
            ParamType.bool,
          ),
        ),
      ),
      FFRoute(
        name: EventWidget.routeName,
        path: EventWidget.routePath,
        requireAuth: true,
        builder: (context, params) => params.isEmpty
            ? NavBarPage(initialPage: 'Event')
            : const EventWidget(),
      ),
      FFRoute(
        name: EventDetailWidget.routeName,
        path: EventDetailWidget.routePath,
        requireAuth: true,
        builder: (context, params) => EventDetailWidget(
          eventId: params.getParam(
            'eventId',
            ParamType.String,
          ),
          payment: params.getParam(
            'payment',
            ParamType.String,
          ),
          sessionId: params.getParam(
            'sessionId',
            ParamType.String,
          ),
        ),
      ),
      FFRoute(
        name: OnBoardingWidget.routeName,
        path: OnBoardingWidget.routePath,
        requireAuth: true,
        builder: (context, params) => const OnBoardingWidget(),
      ),
      FFRoute(
        name: WelcomeWidget.routeName,
        path: WelcomeWidget.routePath,
        builder: (context, params) => const WelcomeWidget(),
      ),
      FFRoute(
        name: ForgotPasswordWidget.routeName,
        path: ForgotPasswordWidget.routePath,
        builder: (context, params) => const ForgotPasswordWidget(),
      ),
      FFRoute(
        name: OnboardingProfileWidget.routeName,
        path: OnboardingProfileWidget.routePath,
        requireAuth: true,
        builder: (context, params) => OnboardingProfileWidget(
          deeplink: params.getParam(
            'deeplink',
            ParamType.bool,
          ),
        ),
      ),
      FFRoute(
          name: DiscoverWidget.routeName,
          path: DiscoverWidget.routePath,
          requireAuth: true,
          builder: (context, params) => params.isEmpty
              ? NavBarPage(initialPage: 'Discover')
              : NavBarPage(
                  initialPage: 'Discover',
                  page: DiscoverWidget(
                    isDeeplink: params.getParam(
                      'isDeeplink',
                      ParamType.bool,
                    ),
                  ),
                )),
      FFRoute(
        name: ProfileWidget.routeName,
        path: ProfileWidget.routePath,
        requireAuth: true,
        builder: (context, params) => params.isEmpty
            ? NavBarPage(initialPage: 'Profile')
            : const ProfileWidget(),
      ),
      FFRoute(
        name: CreateEventWidget.routeName,
        path: CreateEventWidget.routePath,
        requireAuth: true,
        asyncParams: {
          'event': getDoc(['events'], EventsRecord.fromSnapshot),
        },
        builder: (context, params) => CreateEventWidget(
          event: params.getParam(
            'event',
            ParamType.Document,
          ),
        ),
      ),
      FFRoute(
        name: InvitationCodeWidget.routeName,
        path: InvitationCodeWidget.routePath,
        builder: (context, params) => InvitationCodeWidget(
          isDeeplink: params.getParam(
            'isDeeplink',
            ParamType.bool,
          ),
        ),
      ),
      FFRoute(
        name: EditProfileWidget.routeName,
        path: EditProfileWidget.routePath,
        requireAuth: true,
        builder: (context, params) => const EditProfileWidget(),
      ),
      FFRoute(
        name: SearchWidget.routeName,
        path: SearchWidget.routePath,
        requireAuth: true,
        builder: (context, params) => const SearchWidget(),
      ),
      FFRoute(
        name: ContactWidget.routeName,
        path: ContactWidget.routePath,
        requireAuth: true,
        builder: (context, params) => const ContactWidget(),
      ),
      FFRoute(
        name: FAQsWidget.routeName,
        path: FAQsWidget.routePath,
        requireAuth: true,
        builder: (context, params) => const FAQsWidget(),
      ),
      FFRoute(
        name: PrivacyAndPolicyWidget.routeName,
        path: PrivacyAndPolicyWidget.routePath,
        requireAuth: true,
        builder: (context, params) => const PrivacyAndPolicyWidget(),
      ),
      FFRoute(
        name: GroupChatDetailWidget.routeName,
        path: GroupChatDetailWidget.routePath,
        requireAuth: true,
        asyncParams: {
          'chatDoc': getDoc(['chats'], ChatsRecord.fromSnapshot),
        },
        builder: (context, params) => GroupChatDetailWidget(
          chatDoc: params.getParam(
            'chatDoc',
            ParamType.Document,
          ),
        ),
      ),
      FFRoute(
        name: UserProfileDetailWidget.routeName,
        path: UserProfileDetailWidget.routePath,
        requireAuth: true,
        asyncParams: {
          'user': getDoc(['users'], UsersRecord.fromSnapshot),
        },
        builder: (context, params) => UserProfileDetailWidget(
          user: params.getParam(
            'user',
            ParamType.Document,
          ),
        ),
      ),
      FFRoute(
        name: ChatWidget.routeName,
        path: ChatWidget.routePath,
        requireAuth: true,
        builder: (context, params) => params.isEmpty
            ? NavBarPage(initialPage: 'Chat')
            : const ChatWidget(),
      ),
      FFRoute(
        name: ChatGroupCreationWidget.routeName,
        path: ChatGroupCreationWidget.routePath,
        requireAuth: true,
        asyncParams: {
          'chatDoc': getDoc(['chats'], ChatsRecord.fromSnapshot),
        },
        builder: (context, params) => ChatGroupCreationWidget(
          isEdit: params.getParam(
            'isEdit',
            ParamType.bool,
          ),
          chatDoc: params.getParam(
            'chatDoc',
            ParamType.Document,
          ),
        ),
      ),
      FFRoute(
        name: AllAttendeesWidget.routeName,
        path: AllAttendeesWidget.routePath,
        requireAuth: true,
        asyncParams: {
          'event': getDoc(['events'], EventsRecord.fromSnapshot),
        },
        builder: (context, params) => AllAttendeesWidget(
          event: params.getParam(
            'event',
            ParamType.Document,
          ),
        ),
      ),
      FFRoute(
        name: ContactsListWidget.routeName,
        path: ContactsListWidget.routePath,
        requireAuth: true,
        builder: (context, params) => const ContactsListWidget(),
      ),
      FFRoute(
        name: ChatDetailWidget.routeName,
        path: ChatDetailWidget.routePath,
        requireAuth: true,
        asyncParams: {
          'chatDoc': getDoc(['chats'], ChatsRecord.fromSnapshot),
        },
        builder: (context, params) => ChatDetailWidget(
          chatDoc: params.getParam(
            'chatDoc',
            ParamType.Document,
          ),
        ),
      ),
      FFRoute(
        name: AllUsersWidget.routeName,
        path: AllUsersWidget.routePath,
        requireAuth: true,
        builder: (context, params) => const AllUsersWidget(),
      ),
      FFRoute(
        name: SearchChatWidget.routeName,
        path: SearchChatWidget.routePath,
        requireAuth: true,
        builder: (context, params) => const SearchChatWidget(),
      ),
      FFRoute(
        name: TermsPrivacyWidget.routeName,
        path: TermsPrivacyWidget.routePath,
        builder: (context, params) => TermsPrivacyWidget(
          isTerm: params.getParam(
            'isTerm',
            ParamType.bool,
          ),
        ),
      ),
      FFRoute(
        name: PostDetailWidget.routeName,
        path: PostDetailWidget.routePath,
        requireAuth: true,
        asyncParams: {
          'postDoc': getDoc(['posts'], PostsRecord.fromSnapshot),
        },
        builder: (context, params) => PostDetailWidget(
          postDoc: params.getParam(
            'postDoc',
            ParamType.Document,
          ),
        ),
      ),
      FFRoute(
        name: FeedWidget.routeName,
        path: FeedWidget.routePath,
        requireAuth: true,
        builder: (context, params) => params.isEmpty
            ? NavBarPage(initialPage: 'Feed')
            : const FeedWidget(),
      ),
      FFRoute(
        name: CreatePostWidget.routeName,
        path: CreatePostWidget.routePath,
        requireAuth: true,
        builder: (context, params) => CreatePostWidget(
          image: params.getParam(
            'image',
            ParamType.String,
          ),
          caption: params.getParam(
            'caption',
            ParamType.String,
          ),
          feeling: params.getParam(
            'feeling',
            ParamType.String,
          ),
          isEdit: params.getParam(
            'isEdit',
            ParamType.bool,
          ),
          postDoc: params.getParam(
            'postDoc',
            ParamType.DocumentReference,
            isList: false,
            collectionNamePath: ['posts'],
          ),
        ),
      ),
      FFRoute(
        name: AllPendingRequestsWidget.routeName,
        path: AllPendingRequestsWidget.routePath,
        requireAuth: true,
        builder: (context, params) => const AllPendingRequestsWidget(),
      ),
      FFRoute(
        name: FullImageWidget.routeName,
        path: FullImageWidget.routePath,
        requireAuth: true,
        builder: (context, params) => const FullImageWidget(),
      ),
      FFRoute(
        name: QRScanPageWidget.routeName,
        path: QRScanPageWidget.routePath,
        requireAuth: true,
        builder: (context, params) => const QRScanPageWidget(),
      ),
      FFRoute(
        name: NotificationPageWidget.routeName,
        path: NotificationPageWidget.routePath,
        requireAuth: true,
        builder: (context, params) => const NotificationPageWidget(),
      ),
      FFRoute(
        name: EventbriteDashboardWidget.routeName,
        path: EventbriteDashboardWidget.routePath,
        requireAuth: true,
        builder: (context, params) => const EventbriteDashboardWidget(),
      ),
      FFRoute(
        name: PaymentHistoryPageWidget.routeName,
        path: PaymentHistoryPageWidget.routePath,
        requireAuth: true,
        builder: (context, params) => const PaymentHistoryPageWidget(),
      ),
      FFRoute(
        name: PaymentSuccessWidget.routeName,
        path: PaymentSuccessWidget.routePath,
        builder: (context, params) => PaymentSuccessWidget(
          eventId: params.getParam(
            'eventId',
            ParamType.String,
          ),
          payment: params.getParam(
            'payment',
            ParamType.String,
          ),
          sessionId: params.getParam(
            'sessionId',
            ParamType.String,
          ),
        ),
      ),
      FFRoute(
        name: $branchio_dynamic_linking_akp5u6.TestHomePageWidget.routeName,
        path: $branchio_dynamic_linking_akp5u6.TestHomePageWidget.routePath,
        requireAuth: true,
        builder: (context, params) =>
            const $branchio_dynamic_linking_akp5u6.TestHomePageWidget(),
      ),
      FFRoute(
        name: $branchio_dynamic_linking_akp5u6.TestDashboardWidget.routeName,
        path: $branchio_dynamic_linking_akp5u6.TestDashboardWidget.routePath,
        requireAuth: true,
        builder: (context, params) =>
            $branchio_dynamic_linking_akp5u6.TestDashboardWidget(
          title: params.getParam(
            'title',
            ParamType.String,
          ),
        ),
      )
    ].map((r) => r.toRoute(appStateNotifier)).toList(),
    observers: [routeObserver],
  );
}

extension NavParamExtensions on Map<String, String?> {
  Map<String, String> get withoutNulls => Map.fromEntries(
        entries
            .where((e) => e.value != null)
            .map((e) => MapEntry(e.key, e.value!)),
      );
}

extension NavigationExtensions on BuildContext {
  void goNamedAuth(
    String name,
    bool mounted, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, String> queryParameters = const <String, String>{},
    Object? extra,
    bool ignoreRedirect = false,
  }) =>
      !mounted || GoRouter.of(this).shouldRedirect(ignoreRedirect)
          ? null
          : goNamed(
              name,
              pathParameters: pathParameters,
              queryParameters: queryParameters,
              extra: extra,
            );

  void pushNamedAuth(
    String name,
    bool mounted, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, String> queryParameters = const <String, String>{},
    Object? extra,
    bool ignoreRedirect = false,
  }) =>
      !mounted || GoRouter.of(this).shouldRedirect(ignoreRedirect)
          ? null
          : pushNamed(
              name,
              pathParameters: pathParameters,
              queryParameters: queryParameters,
              extra: extra,
            );

  void safePop() {
    // If there is only one route on the stack, navigate to the initial
    // page instead of popping.
    if (canPop()) {
      pop();
    } else {
      go('/');
    }
  }
}

extension GoRouterExtensions on GoRouter {
  AppStateNotifier get appState => AppStateNotifier.instance;
  void prepareAuthEvent([bool ignoreRedirect = false]) =>
      appState.hasRedirect() && !ignoreRedirect
          ? null
          : appState.updateNotifyOnAuthChange(false);
  bool shouldRedirect(bool ignoreRedirect) =>
      !ignoreRedirect && appState.hasRedirect();
  void clearRedirectLocation() => appState.clearRedirectLocation();
  void setRedirectLocationIfUnset(String location) =>
      appState.updateNotifyOnAuthChange(false);
}

extension _GoRouterStateExtensions on GoRouterState {
  Map<String, dynamic> get extraMap =>
      extra != null ? extra as Map<String, dynamic> : {};
  Map<String, dynamic> get allParams => <String, dynamic>{}
    ..addAll(pathParameters)
    ..addAll(uri.queryParameters)
    ..addAll(extraMap);
  TransitionInfo get transitionInfo => extraMap.containsKey(kTransitionInfoKey)
      ? extraMap[kTransitionInfoKey] as TransitionInfo
      : TransitionInfo.appDefault();
}

class FFParameters {
  FFParameters(this.state, [this.asyncParams = const {}]);

  final GoRouterState state;
  final Map<String, Future<dynamic> Function(String)> asyncParams;

  Map<String, dynamic> futureParamValues = {};

  // Parameters are empty if the params map is empty or if the only parameter
  // present is the special extra parameter reserved for the transition info.
  bool get isEmpty =>
      state.allParams.isEmpty ||
      (state.allParams.length == 1 &&
          state.extraMap.containsKey(kTransitionInfoKey));
  bool isAsyncParam(MapEntry<String, dynamic> param) =>
      asyncParams.containsKey(param.key) && param.value is String;
  bool get hasFutures => state.allParams.entries.any(isAsyncParam);
  Future<bool> completeFutures() => Future.wait(
        state.allParams.entries.where(isAsyncParam).map(
          (param) async {
            final doc = await asyncParams[param.key]!(param.value)
                .onError((_, __) => null);
            if (doc != null) {
              futureParamValues[param.key] = doc;
              return true;
            }
            return false;
          },
        ),
      ).onError((_, __) => [false]).then((v) => v.every((e) => e));

  dynamic getParam<T>(
    String paramName,
    ParamType type, {
    bool isList = false,
    List<String>? collectionNamePath,
    StructBuilder<T>? structBuilder,
  }) {
    if (futureParamValues.containsKey(paramName)) {
      return futureParamValues[paramName];
    }
    if (!state.allParams.containsKey(paramName)) {
      return null;
    }
    final param = state.allParams[paramName];
    // Got parameter from `extras`, so just directly return it.
    if (param is! String) {
      return param;
    }
    // Return serialized value.
    return deserializeParam<T>(
      param,
      type,
      isList,
      collectionNamePath: collectionNamePath,
      structBuilder: structBuilder,
    );
  }
}

class FFRoute {
  const FFRoute({
    required this.name,
    required this.path,
    required this.builder,
    this.requireAuth = false,
    this.asyncParams = const {},
    this.routes = const [],
  });

  final String name;
  final String path;
  final bool requireAuth;
  final Map<String, Future<dynamic> Function(String)> asyncParams;
  final Widget Function(BuildContext, FFParameters) builder;
  final List<GoRoute> routes;

  GoRoute toRoute(AppStateNotifier appStateNotifier) => GoRoute(
        name: name,
        path: path,
        redirect: (context, state) {
          if (appStateNotifier.shouldRedirect) {
            final redirectLocation = appStateNotifier.getRedirectLocation();
            appStateNotifier.clearRedirectLocation();
            return redirectLocation;
          }

          if (requireAuth && !appStateNotifier.loggedIn) {
            appStateNotifier.setRedirectLocationIfUnset(state.uri.toString());
            return '/welcome';
          }
          return null;
        },
        pageBuilder: (context, state) {
          fixStatusBarOniOS16AndBelow(context);
          final ffParams = FFParameters(state, asyncParams);
          final page = ffParams.hasFutures
              ? FutureBuilder(
                  future: ffParams.completeFutures(),
                  builder: (context, _) => builder(context, ffParams),
                )
              : builder(context, ffParams);
          final child = appStateNotifier.loading
              ? Container(
                  color: FlutterFlowTheme.of(context).primary,
                  child: Center(
                    child: Image.asset(
                      'assets/images/Logo_2.png',
                      width: 200.0,
                      fit: BoxFit.contain,
                    ),
                  ),
                )
              : PushNotificationsHandler(child: page);

          final transitionInfo = state.transitionInfo;
          return transitionInfo.hasTransition
              ? CustomTransitionPage(
                  key: state.pageKey,
                  child: child,
                  transitionDuration: transitionInfo.duration,
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) =>
                          PageTransition(
                    type: transitionInfo.transitionType,
                    duration: transitionInfo.duration,
                    reverseDuration: transitionInfo.duration,
                    alignment: transitionInfo.alignment,
                    child: child,
                  ).buildTransitions(
                    context,
                    animation,
                    secondaryAnimation,
                    child,
                  ),
                )
              : MaterialPage(key: state.pageKey, child: child);
        },
        routes: routes,
      );
}

class TransitionInfo {
  const TransitionInfo({
    required this.hasTransition,
    this.transitionType = PageTransitionType.fade,
    this.duration = const Duration(milliseconds: 300),
    this.alignment,
  });

  final bool hasTransition;
  final PageTransitionType transitionType;
  final Duration duration;
  final Alignment? alignment;

  static TransitionInfo appDefault() =>
      const TransitionInfo(hasTransition: false);
}

class RootPageContext {
  const RootPageContext(this.isRootPage, [this.errorRoute]);
  final bool isRootPage;
  final String? errorRoute;

  static bool isInactiveRootPage(BuildContext context) {
    final rootPageContext = context.read<RootPageContext?>();
    final isRootPage = rootPageContext?.isRootPage ?? false;
    final location = GoRouterState.of(context).uri.toString();
    return isRootPage &&
        location != '/' &&
        location != rootPageContext?.errorRoute;
  }

  static Widget wrap(Widget child, {String? errorRoute}) => Provider.value(
        value: RootPageContext(true, errorRoute),
        child: child,
      );
}

extension GoRouterLocationExtension on GoRouter {
  String getCurrentLocation() {
    final RouteMatch lastMatch = routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : routerDelegate.currentConfiguration;
    return matchList.uri.toString();
  }
}
