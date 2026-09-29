import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/common_strings.dart';
import '../../../../core/localization/locale_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/product_publish_repository.dart';
import '../cubit/publish_product_cubit.dart';
import '../cubit/publish_product_state.dart';
import '../l10n/products_strings.dart';
import '../widgets/add_product/listing_content_card.dart';
import '../widgets/add_product/platform_targets_panel.dart';
import '../widgets/add_product/product_summary_card.dart';

/// Publish an existing Al-Bayan product to delivery platforms.
class PublishProductPage extends StatelessWidget {
  const PublishProductPage({
    super.key,
    required this.product,
    required this.onClose,
  });

  final ProductModel product;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PublishProductCubit(
        product: product,
        repository: context.read<ProductPublishRepository>(),
      ),
      child: _PublishProductView(onClose: onClose),
    );
  }
}

class _PublishProductView extends StatelessWidget {
  const _PublishProductView({required this.onClose});

  final VoidCallback onClose;

  static String _errorText(
    PublishProductError error,
    ProductsStrings s,
    CommonStrings common,
  ) {
    switch (error) {
      case NoPlatformSelected():
        return s.noPlatformSelected;
      case PlatformsPublishFailed(:final count):
        return s.platformsFailed(count);
      case PlatformPublishFailed(:final platformId, :final outcome):
        final platform = common.platformName(platformId);
        return s.platformFailed(
          platform,
          s.publishNotice(outcome.notice, platform, outcome.detail),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PublishProductCubit, PublishProductState>(
      listenWhen: (p, c) => p.status != c.status || p.error != c.error,
      listener: (context, state) {
        final s = context.productsStrings;
        final common = context.commonStrings;
        final error = state.error;
        if (error != null && state.status == PublishProductStatus.failure) {
          if (error is NoPlatformSelected) {
            AppSnackBar.info(context, s.noPlatformSelected);
          } else {
            AppSnackBar.error(
              context,
              title: s.publishFailedTitle,
              message: _errorText(error, s, common),
            );
          }
        }
        if (state.status == PublishProductStatus.success) {
          AppSnackBar.success(
            context,
            s.publishedTitle,
            message: s.publishSucceeded(
              state.product.name,
              [
                for (final id in state.publishedPlatformIds)
                  common.platformName(id),
              ],
              [
                for (final id in state.processingPlatformIds)
                  common.platformName(id),
              ],
            ),
          );
          onClose();
        }
      },
      buildWhen: (p, c) => p.status != c.status,
      builder: (context, state) {
        if (state.status == PublishProductStatus.success) {
          return const SizedBox.shrink();
        }

        final submitting = state.status == PublishProductStatus.submitting;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              productName: state.product.name,
              submitting: submitting,
              onClose: onClose,
              onPublish: () => context.read<PublishProductCubit>().submit(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final summary = ProductSummaryCard(product: state.product);
                    if (constraints.maxWidth >= 980) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 4,
                            child: Column(
                              children: [
                                Expanded(flex: 2, child: summary),
                                const SizedBox(height: 12),
                                const Expanded(
                                  flex: 3,
                                  child: ListingContentCard(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            flex: 6,
                            child: PlatformTargetsPanel(),
                          ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: summary),
                              const SizedBox(width: 12),
                              const Expanded(child: ListingContentCard()),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Expanded(flex: 6, child: PlatformTargetsPanel()),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.productName,
    required this.submitting,
    required this.onClose,
    required this.onPublish,
  });

  final String productName;
  final bool submitting;
  final VoidCallback onClose;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    final s = context.productsStrings;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 16, 12),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: submitting ? null : onClose,
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            tooltip: s.backToProducts,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.addToPlatforms,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  productName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: submitting ? null : onClose,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              side: const BorderSide(color: AppTheme.border),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            child: Text(context.commonStrings.cancel),
          ),
          const SizedBox(width: 8),
          BlocSelector<PublishProductCubit, PublishProductState, bool>(
            selector: (s) => s.canSubmit && !submitting,
            builder: (context, canSubmit) {
              return FilledButton.icon(
                onPressed: canSubmit ? onPublish : null,
                icon: submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add_to_photos_outlined, size: 18),
                label: Text(submitting ? s.adding : s.addToPlatforms),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  disabledBackgroundColor: AppTheme.primary.withValues(
                    alpha: 0.4,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
