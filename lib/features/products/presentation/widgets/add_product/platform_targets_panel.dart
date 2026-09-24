import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/theme/platform_colors.dart';
import '../../../data/models/listing_models.dart';
import '../../../data/repositories/product_publish_repository.dart';
import '../../cubit/publish_product_cubit.dart';
import '../../cubit/publish_product_state.dart';
import 'hs_listing_fields.dart';
import 'keeta_listing_fields.dart';

class PlatformTargetsPanel extends StatelessWidget {
  const PlatformTargetsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: _PanelHeader(),
          ),
          const Divider(height: 1, color: AppTheme.border),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: ProductPublishRepository.supportedPlatforms.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final platformId =
                    ProductPublishRepository.supportedPlatforms[index];
                return BlocSelector<
                  PublishProductCubit,
                  PublishProductState,
                  PlatformPublishDraft
                >(
                  key: ValueKey(platformId),
                  selector: (s) => s.platforms[platformId]!,
                  builder: (context, draft) {
                    return RepaintBoundary(
                      child: PlatformTargetCard(draft: draft),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),
          const _PublishSummary(),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.hub_outlined,
            size: 18,
            color: Color(0xFF059669),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Publish to platforms',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                'Choose where this product goes live',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () =>
              context.read<PublishProductCubit>().selectAllPlatforms(),
          child: const Text('Select all', style: TextStyle(fontSize: 12)),
        ),
        TextButton(
          onPressed: () => context.read<PublishProductCubit>().clearPlatforms(),
          child: const Text('Clear', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}

class PlatformTargetCard extends StatelessWidget {
  const PlatformTargetCard({super.key, required this.draft});

  final PlatformPublishDraft draft;

  /// Status line under the platform name, and its color.
  (String, Color) _status(Color accent) => switch (draft.phase) {
    _ when !draft.enabled => ('Not selected', AppTheme.textMuted),
    PublishPhase.idle => ('Ready to publish', accent),
    PublishPhase.publishing => ('Publishing…', accent),
    PublishPhase.published => ('Published', const Color(0xFF059669)),
    PublishPhase.processing => (
      draft.resultMessage ?? 'Processing…',
      const Color(0xFFD97706),
    ),
    PublishPhase.failed => (draft.resultMessage ?? 'Failed', AppTheme.coral),
  };

  @override
  Widget build(BuildContext context) {
    final color = PlatformColors.of(draft.platformId);
    final (statusText, statusColor) = _status(color);
    final locked = draft.phase == PublishPhase.publishing;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: draft.enabled
            ? color.withValues(alpha: 0.04)
            : AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: draft.enabled
              ? color.withValues(alpha: 0.45)
              : AppTheme.border,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: locked
                ? null
                : () => context.read<PublishProductCubit>().togglePlatform(
                    draft.platformId,
                    !draft.enabled,
                  ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          draft.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: draft.enabled
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          statusText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: draft.enabled,
                    activeThumbColor: color,
                    onChanged: locked
                        ? null
                        : (v) => context
                              .read<PublishProductCubit>()
                              .togglePlatform(draft.platformId, v),
                  ),
                ],
              ),
            ),
          ),
          // Built only while selected: a hidden form would still build and
          // start loading that platform's categories.
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: draft.enabled
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Divider(height: 1, color: AppTheme.border),
                        const SizedBox(height: 10),
                        switch (draft.listing) {
                          final KeetaListing listing => KeetaListingFields(
                            listing: listing,
                            accent: color,
                          ),
                          final HsListing listing => HsListingFields(
                            listing: listing,
                            accent: color,
                          ),
                        },
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _PublishSummary extends StatelessWidget {
  const _PublishSummary();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<PublishProductCubit, PublishProductState, (int, int)>(
      selector: (s) => (s.selectedCount, s.platforms.length),
      builder: (context, counts) {
        final (selected, total) = counts;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : selected / total,
                    minHeight: 6,
                    backgroundColor: AppTheme.border,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                '$selected of $total platforms',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
