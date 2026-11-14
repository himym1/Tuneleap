import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/empty_state.dart';
import 'package:navidrome_player/ui/widgets/loading_skeleton.dart';
import 'package:navidrome_player/ui/widgets/page_back_button.dart';

class LibraryRadioScreen extends ConsumerWidget {
  const LibraryRadioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stations = ref.watch(radioStationsProvider);
    final isMobile = AppBreakpoints.isMobile(MediaQuery.of(context).size.width);
    final h = isMobile
        ? AppDimensions.paddingMobile
        : AppDimensions.paddingDesktop;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(h, h, h, 16),
            child: Row(
              children: [
                if (context.canPop()) ...[
                  const PageBackButton(
                    compact: true,
                    fallbackRoute: '/library/songs',
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    S.of(context).libraryRadioTitle,
                    style: Theme.of(context).textTheme.pageTitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: stations.when(
              loading: () => SongListSkeleton(
                itemCount: 6,
                padding: EdgeInsets.symmetric(horizontal: h, vertical: 8),
              ),
              error: (_, _) => ErrorState(
                message: S.of(context).commonError,
                onRetry: () => ref.invalidate(radioStationsProvider),
                retryLabel: S.of(context).commonRetry,
              ),
              data: (items) {
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.radio_rounded,
                    message: S.of(context).libraryRadioEmpty,
                  );
                }
                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: h, vertical: 8),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final station = items[index];
                    return ListTile(
                      leading: Container(
                        width: AppDimensions.coverList,
                        height: AppDimensions.coverList,
                        decoration: BoxDecoration(
                          color: context.colors.primarySoft,
                          borderRadius: BorderRadius.circular(
                            AppDimensions.cardRadiusSmall,
                          ),
                        ),
                        child: Icon(
                          Icons.radio_rounded,
                          color: context.colors.primary,
                        ),
                      ),
                      title: Text(
                        station.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: station.homePageUrl == null
                          ? null
                          : Text(
                              station.homePageUrl!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      onTap: () => ref.read(audioPlayerServiceProvider).playAll(
                        [station.toSong()],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
