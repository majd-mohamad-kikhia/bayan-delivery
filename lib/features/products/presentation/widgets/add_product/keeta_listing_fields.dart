import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/platforms/keeta/keeta_types.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../data/models/listing_models.dart';
import '../../cubit/publish_product_cubit.dart';
import '../../utils/product_formatters.dart';
import 'listing_form_fields.dart';

/// Every field Keeta's `/product/spu/batchcreate` takes for a single-SKU
/// product (SPU + SKU schema, Keeta menu OpenAPI).
class KeetaListingFields extends StatefulWidget {
  const KeetaListingFields({
    super.key,
    required this.listing,
    required this.accent,
  });

  final KeetaListing listing;
  final Color accent;

  @override
  State<KeetaListingFields> createState() => _KeetaListingFieldsState();
}

class _KeetaListingFieldsState extends State<KeetaListingFields> {
  late final Future<List<String>> _categories = context
      .read<PublishProductCubit>()
      .categoryNames('keeta');

  late String _hoursFrom = widget.listing.sellingHours?.start ?? '';
  late String _hoursTo = widget.listing.sellingHours?.end ?? '';

  void _update(KeetaListing Function(KeetaListing listing) change) => context
      .read<PublishProductCubit>()
      .updateListing<KeetaListing>('keeta', change);

  void _updateHours() {
    final hours = KeetaSellingHours.tryParse(_hoursFrom, _hoursTo);
    _update((l) => l.copyWith(sellingHours: () => hours));
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final accent = widget.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListingSwitch(
          label: 'Available',
          hint: 'status — off lists it as unavailable',
          value: listing.available,
          accent: accent,
          onChanged: (v) => _update((l) => l.copyWith(available: v)),
        ),
        ListingSwitch(
          label: 'Signature item',
          hint: 'isSpecialty — max 15 per store',
          value: listing.signature,
          accent: accent,
          onChanged: (v) => _update((l) => l.copyWith(signature: v)),
        ),
        const SizedBox(height: 8),
        ListingPair(
          ListingNumberField(
            label: 'Delivery price (SAR) *',
            initial: listing.price,
            onChanged: (v) =>
                _update((l) => l.copyWith(price: v?.toDouble() ?? 0)),
          ),
          ListingCategoryField(
            label: 'Menu category *',
            initial: listing.category,
            hint: 'Existing or new category',
            suggestions: _categories,
            onChanged: (v) => _update((l) => l.copyWith(category: v)),
          ),
        ),

        ListingSection(
          title: 'Selling time',
          hint: 'availableTime',
          children: [
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('All day')),
                ButtonSegment(value: true, label: Text('Daily hours')),
              ],
              selected: {listing.limitedHours},
              onSelectionChanged: (s) =>
                  _update((l) => l.copyWith(limitedHours: s.first)),
            ),
            if (listing.limitedHours) ...[
              const SizedBox(height: 10),
              ListingPair(
                ListingTextField(
                  label: 'From (HH:mm)',
                  initial: _hoursFrom,
                  hint: '06:00',
                  onChanged: (v) {
                    _hoursFrom = v;
                    _updateHours();
                  },
                ),
                ListingTextField(
                  label: 'To (HH:mm)',
                  initial: _hoursTo,
                  hint: '11:00',
                  onChanged: (v) {
                    _hoursTo = v;
                    _updateHours();
                  },
                ),
              ),
            ],
          ],
        ),

        ListingSection(
          title: 'Pickup',
          hint: 'userGetModeList — delivery is always on',
          children: [
            ListingSwitch(
              label: 'Allow pickup',
              value: listing.pickup,
              accent: accent,
              onChanged: (v) => _update((l) => l.copyWith(pickup: v)),
            ),
            if (listing.pickup)
              ListingNumberField(
                label: 'Pickup price (SAR) *',
                initial: listing.pickupPrice,
                hint: formatSar(listing.price),
                onChanged: (v) => _update(
                  (l) => l.copyWith(pickupPrice: () => v?.toDouble()),
                ),
              ),
          ],
        ),

        ListingSection(
          title: 'Allergens',
          hint: 'Required in Saudi Arabia (SFDA) — leave empty if none',
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final allergen in KeetaAllergen.values)
                  FilterChip(
                    label: Text(
                      allergen.wire,
                      style: const TextStyle(fontSize: 12),
                    ),
                    selected: listing.allergens.contains(allergen),
                    selectedColor: accent.withValues(alpha: 0.12),
                    checkmarkColor: accent,
                    visualDensity: VisualDensity.compact,
                    onSelected: (selected) => _update(
                      (l) => l.copyWith(
                        allergens: selected
                            ? {...l.allergens, allergen}
                            : ({...l.allergens}..remove(allergen)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),

        _NutritionSection(listing: listing, onUpdate: _update),
      ],
    );
  }
}

/// `nutritionalInfo`, `servingSize`, `caffeine` — collapsed until needed.
class _NutritionSection extends StatelessWidget {
  const _NutritionSection({required this.listing, required this.onUpdate});

  final KeetaListing listing;
  final void Function(KeetaListing Function(KeetaListing)) onUpdate;

  @override
  Widget build(BuildContext context) {
    final filled = listing.nutrition.length;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 4),
          title: Text(
            'Nutrition facts${filled == 0 ? '' : ' ($filled)'}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          subtitle: const Text(
            'Calories are shown on menus in Saudi Arabia',
            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
          children: [
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.9,
              children: [
                for (final nutrient in KeetaNutrient.values)
                  ListingNumberField(
                    label: '${nutrient.label} (${nutrient.unit})',
                    initial: listing.nutrition[nutrient],
                    decimal: false,
                    onChanged: (v) => onUpdate(
                      (l) => l.copyWith(
                        nutrition: v == null
                            ? ({...l.nutrition}..remove(nutrient))
                            : {...l.nutrition, nutrient: v.toInt()},
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ListingPair(
              ListingNumberField(
                label: 'Serves (1–9 people)',
                initial: listing.servingSize,
                decimal: false,
                onChanged: (v) =>
                    onUpdate((l) => l.copyWith(servingSize: () => v?.toInt())),
              ),
              ListingNumberField(
                label: 'Caffeine (mg)',
                initial: listing.caffeineMg,
                onChanged: (v) => onUpdate(
                  (l) => l.copyWith(caffeineMg: () => v?.toDouble()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
