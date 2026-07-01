import 'package:flutter/material.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final ValueNotifier<int> mainNavTabNotifier = ValueNotifier<int>(0);
final ValueNotifier<int> homeCategoryNotifier = ValueNotifier<int>(0);
