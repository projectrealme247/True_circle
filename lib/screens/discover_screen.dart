import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/app_card.dart';
import '../core/widgets/app_scaffold.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScrollScaffold(
      title: 'Discover',
      showBackButton: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.tune_rounded),
          onPressed: () {},
        ),
      ],
      slivers: [
        SliverPadding(
          padding: AppSpacing.screenPadding,
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: AppProfileCard(
                  imageUrl: 'https://i.pravatar.cc/400?img=$index',
                  name: 'Alex Chen',
                  subtitle:
                      'Creative professional • Early riser • Clean & tidy',
                  matchPercentage: 92,
                  badge: 'Verified',
                  onTap: () {},
                  onFavorite: () {},
                ),
              ),
              childCount: 10,
            ),
          ),
        ),
      ],
    );
  }
}
