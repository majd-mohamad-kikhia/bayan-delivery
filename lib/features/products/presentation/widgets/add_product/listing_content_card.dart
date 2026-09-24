import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../data/models/listing_models.dart';
import '../../cubit/publish_product_cubit.dart';
import 'listing_form_fields.dart';

/// Fields every platform gets: names, descriptions, images, barcode.
/// Prefilled from Al-Bayan; edits here only affect the platform listing.
class ListingContentCard extends StatelessWidget {
  const ListingContentCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PublishProductCubit>();
    // Read once: the fields own their text from here on.
    final content = cubit.state.content;
    void update(ListingContent Function(ListingContent) change) =>
        cubit.updateContent(change);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _Header(),
          const SizedBox(height: 16),
          ListingPair(
            ListingTextField(
              label: 'Name (English) *',
              initial: content.nameEn,
              onChanged: (v) => update((c) => c.copyWith(nameEn: v)),
            ),
            ListingTextField(
              label: 'Name (Arabic)',
              initial: content.nameAr,
              textDirection: TextDirection.rtl,
              onChanged: (v) => update((c) => c.copyWith(nameAr: v)),
            ),
          ),
          const SizedBox(height: 10),
          ListingTextField(
            label: 'Description (English)',
            initial: content.descriptionEn,
            maxLines: 3,
            hint: 'Size, ingredients, what’s in the pack…',
            onChanged: (v) => update((c) => c.copyWith(descriptionEn: v)),
          ),
          const SizedBox(height: 10),
          ListingTextField(
            label: 'Description (Arabic)',
            initial: content.descriptionAr,
            maxLines: 3,
            textDirection: TextDirection.rtl,
            onChanged: (v) => update((c) => c.copyWith(descriptionAr: v)),
          ),
          const SizedBox(height: 10),
          ListingTextField(
            label: 'Barcode (GTIN)',
            initial: content.barcode,
            hint: 'Required on HungerStation unless sold by weight',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (v) => update((c) => c.copyWith(barcode: v.trim())),
          ),
          const SizedBox(height: 10),
          ListingTextField(
            label: 'Image URLs (one per line)',
            initial: content.imageUrls.join('\n'),
            maxLines: 3,
            hint: 'https://…/product.jpg',
            keyboardType: TextInputType.url,
            onChanged: (v) => update(
              (c) => c.copyWith(
                imageUrls: [
                  for (final line in v.split('\n'))
                    if (line.trim().isNotEmpty) line.trim(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'JPG or PNG, publicly reachable. Keeta: at least 600×450, up to 5 MB. '
            'HungerStation: at least 400×400, white background, product centered.',
            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.storefront_outlined,
            size: 18,
            color: Color(0xFFEA580C),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Listing details',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                'What customers see on every platform',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
