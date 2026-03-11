import 'dart:ui';

import 'package:navidrome_player/l10n/app_localizations.dart';

Locale resolveSupportedLocale(Locale locale) {
  for (final supportedLocale in S.supportedLocales) {
    if (supportedLocale.languageCode == locale.languageCode) {
      return supportedLocale;
    }
  }
  return S.supportedLocales.first;
}

S systemLocalizations({Locale? locale}) {
  return lookupS(
    resolveSupportedLocale(locale ?? PlatformDispatcher.instance.locale),
  );
}
