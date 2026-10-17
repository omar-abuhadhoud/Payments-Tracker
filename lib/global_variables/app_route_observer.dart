import 'package:flutter/material.dart';

/// Lets screens know when they become visible again (e.g. to reload data).
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();
