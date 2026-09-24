import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/listing_models.dart';
import '../../cubit/publish_product_cubit.dart';
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
    final listing = widget.listing;
    final accent = widget.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListingSwitch(
          label: 'Available',
          hint: 'active — applied right after the product is added',
          value: listing.available,
          accent: accent,
          onChanged: (v) => _update((l) => l.copyWith(available: v)),
        ),
        const SizedBox(height: 8),
        ListingPair(
          ListingNumberField(
            label: 'Price (SAR) *',
            initial: listing.price,
            onChanged: (v) =>
                _update((l) => l.copyWith(price: v?.toDouble() ?? 0)),
          ),
          ListingCategoryField(
            label: 'Category',
            initial: listing.category,
            hint: 'From HungerStation’s list',
            suggestions: _categories,
            onChanged: (v) => _update((l) => l.copyWith(category: v)),
          ),
        ),

        ListingSection(
          title: 'Stock',
          hint: 'quantity at or below the sales buffer turns the product off',
          children: [
            ListingPair(
              ListingNumberField(
                label: 'Quantity',
                initial: listing.quantity,
                decimal: false,
                onChanged: (v) =>
                    _update((l) => l.copyWith(quantity: () => v?.toInt())),
              ),
              ListingNumberField(
                label: 'Max per order',
                initial: listing.maxPerOrder,
                decimal: false,
                hint: 'No limit',
                onChanged: (v) =>
                    _update((l) => l.copyWith(maxPerOrder: () => v?.toInt())),
              ),
            ),
          ],
        ),

        ListingSection(
          title: 'Sold by weight',
          hint: 'is_sold_by_weight — no barcode needed when on',
          children: [
            ListingSwitch(
              label: 'Priced by weight',
              value: listing.soldByWeight,
              accent: accent,
              onChanged: (v) => _update((l) => l.copyWith(soldByWeight: v)),
            ),
            if (listing.soldByWeight) ...[
              const SizedBox(height: 6),
              ListingWeightField(
                label: 'Base weight the price is for *',
                initial: listing.baseWeight,
                hint: '1',
                onChanged: (v) =>
                    _update((l) => l.copyWith(baseWeight: () => v)),
              ),
              const SizedBox(height: 10),
              ListingWeightField(
                label: 'Average weight per piece',
                initial: listing.averageWeightPerPiece,
                onChanged: (v) =>
                    _update((l) => l.copyWith(averageWeightPerPiece: () => v)),
              ),
              const SizedBox(height: 10),
              ListingWeightField(
                label: 'Minimum order weight',
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
