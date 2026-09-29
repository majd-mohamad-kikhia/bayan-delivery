import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/listing_models.dart';
import '../../cubit/publish_product_cubit.dart';
import '../../l10n/products_strings.dart';
import 'listing_form_fields.dart';

/// Every field HungerStation's `POST /catalog` takes, plus the ones only
/// `PUT /catalog` can set (active, quantity, max per order).
class HsListingFields extends StatefulWidget {
  const HsListingFields({
    super.key,
    required this.listing,
    required this.accent,
  });

  final HsListing listing;
  final Color accent;

  @override
  State<HsListingFields> createState() => _HsListingFieldsState();
}

class _HsListingFieldsState extends State<HsListingFields> {
  late final Future<List<String>> _categories = context
      .read<PublishProductCubit>()
      .categoryNames('hungerstation');

  void _update(HsListing Function(HsListing listing) change) => context
      .read<PublishProductCubit>()
      .updateListing<HsListing>('hungerstation', change);

  @override
  Widget build(BuildContext context) {
    final s = context.productsStrings;
    final listing = widget.listing;
    final accent = widget.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListingSwitch(
          label: s.available,
          hint: s.hsAvailableHint,
          value: listing.available,
          accent: accent,
          onChanged: (v) => _update((l) => l.copyWith(available: v)),
        ),
        const SizedBox(height: 8),
        ListingPair(
          ListingNumberField(
            label: s.priceRequired,
            initial: listing.price,
            onChanged: (v) =>
                _update((l) => l.copyWith(price: v?.toDouble() ?? 0)),
          ),
          ListingCategoryField(
            label: s.category,
            initial: listing.category,
            hint: s.hsCategoryHint,
            suggestions: _categories,
            onChanged: (v) => _update((l) => l.copyWith(category: v)),
          ),
        ),

        ListingSection(
          title: s.stock,
          hint: s.stockHint,
          children: [
            ListingPair(
              ListingNumberField(
                label: s.quantity,
                initial: listing.quantity,
                decimal: false,
                onChanged: (v) =>
                    _update((l) => l.copyWith(quantity: () => v?.toInt())),
              ),
              ListingNumberField(
                label: s.maxPerOrder,
                initial: listing.maxPerOrder,
                decimal: false,
                hint: s.noLimit,
                onChanged: (v) =>
                    _update((l) => l.copyWith(maxPerOrder: () => v?.toInt())),
              ),
            ),
          ],
        ),

        ListingSection(
          title: s.soldByWeight,
          hint: s.soldByWeightHint,
          children: [
            ListingSwitch(
              label: s.pricedByWeight,
              value: listing.soldByWeight,
              accent: accent,
              onChanged: (v) => _update((l) => l.copyWith(soldByWeight: v)),
            ),
            if (listing.soldByWeight) ...[
              const SizedBox(height: 6),
              ListingWeightField(
                label: s.baseWeightRequired,
                initial: listing.baseWeight,
                hint: '1',
                onChanged: (v) =>
                    _update((l) => l.copyWith(baseWeight: () => v)),
              ),
              const SizedBox(height: 10),
              ListingWeightField(
                label: s.averageWeightPerPiece,
                initial: listing.averageWeightPerPiece,
                onChanged: (v) =>
                    _update((l) => l.copyWith(averageWeightPerPiece: () => v)),
              ),
              const SizedBox(height: 10),
              ListingWeightField(
                label: s.minimumOrderWeight,
                initial: listing.minimumStartingWeight,
                onChanged: (v) =>
                    _update((l) => l.copyWith(minimumStartingWeight: () => v)),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
