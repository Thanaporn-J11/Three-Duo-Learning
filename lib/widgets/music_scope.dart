import 'package:flutter/material.dart';

import '../services/sfx.dart';

/// Tells [MusicScope]s when their screen is shown or covered. Only full
/// screens count, so a dialog opening on top does not stop the music.
class MusicRouteObserver extends RouteObserver<ModalRoute<void>> {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) super.didPop(route, previousRoute);
  }
}

final MusicRouteObserver musicRouteObserver = MusicRouteObserver();

/// Wrap a menu screen with this and the background music plays while that
/// screen is the one the child sees (and the player has music turned on).
class MusicScope extends StatefulWidget {
  const MusicScope({super.key, required this.child});

  final Widget child;

  @override
  State<MusicScope> createState() => _MusicScopeState();
}

class _MusicScopeState extends State<MusicScope> with RouteAware {
  ModalRoute<void>? _route;
  bool _active = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route) {
      if (_route != null) musicRouteObserver.unsubscribe(this);
      _route = route;
      if (route != null) musicRouteObserver.subscribe(this, route);
    }
  }

  void _enter() {
    if (_active) return;
    _active = true;
    Sfx.musicScopeEnter();
  }

  void _exit() {
    if (!_active) return;
    _active = false;
    Sfx.musicScopeExit();
  }

  @override
  void didPush() => _enter();

  @override
  void didPopNext() => _enter();

  @override
  void didPushNext() => _exit();

  @override
  void didPop() => _exit();

  @override
  void dispose() {
    musicRouteObserver.unsubscribe(this);
    _exit();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
