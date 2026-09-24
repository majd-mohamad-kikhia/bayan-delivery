import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/platforms/hungerstation/hs_types.dart';
import '../../../../../core/theme/app_theme.dart';
import 'add_product_field.dart';

/// Form fields for the publish screen. Each owns its controller and only
/// reports changes, so typing rebuilds nothing but the platform card it
/// belongs to.

/// A titled group of fields inside a platform card.
class ListingSection extends StatelessWidget {
  const ListingSection({
    super.key,
    required this.title,
    required this.children,
    this.hint,
  });

  final String title;
  final String? hint;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: AppTheme.textMuted,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(
              hint!,
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

/// Label + switch on one line.
class ListingSwitch extends StatelessWidget {
  const ListingSwitch({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.accent,
    this.hint,
  });

  final String label;
  final String? hint;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: value ? AppTheme.textPrimary : AppTheme.textSecondary,
                ),
              ),
              if (hint != null)
                Text(
                  hint!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          activeThumbColor: accent,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Free text; reports the trimmed-as-typed value.
class ListingTextField extends StatefulWidget {
  const ListingTextField({
    super.key,
    required this.label,
    required this.initial,
    required this.onChanged,
    this.hint,
    this.maxLines = 1,
    this.textDirection,
    this.keyboardType,
    this.inputFormatters,
  });

  final String label;
  final String initial;
  final ValueChanged<String> onChanged;
  final String? hint;
  final int maxLines;
  final TextDirection? textDirection;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<ListingTextField> createState() => _ListingTextFieldState();
}

class _ListingTextFieldState extends State<ListingTextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AddProductField(
      label: widget.label,
      controller: _controller,
      hint: widget.hint,
      maxLines: widget.maxLines,
      textDirection: widget.textDirection,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      onChanged: widget.onChanged,
    );
  }
}

/// Numeric input; reports null while empty or unparseable.
class ListingNumberField extends StatelessWidget {
  const ListingNumberField({
    super.key,
    required this.label,
    required this.initial,
    required this.onChanged,
    this.decimal = true,
    this.hint,
  });

  final String label;
  final num? initial;
  final ValueChanged<num?> onChanged;
  final bool decimal;
  final String? hint;

  static String format(num? value) {
    if (value == null) return '';
    if (value is int || value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return ListingTextField(
      label: label,
      initial: format(initial),
      hint: hint,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(decimal ? r'[\d.]' : r'\d')),
      ],
      onChanged: (text) => onChanged(
        text.trim().isEmpty
            ? null
            : (decimal ? double.tryParse(text) : int.tryParse(text)),
      ),
    );
  }
}

/// Text field with suggestions from the platform's existing categories.
/// Suggestions load once; free text is still allowed (Keeta creates
/// missing categories).
class ListingCategoryField extends StatefulWidget {
  const ListingCategoryField({
    super.key,
    required this.label,
    required this.initial,
    required this.suggestions,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final String initial;
  final Future<List<String>> suggestions;
  final ValueChanged<String> onChanged;
  final String? hint;

  @override
  State<ListingCategoryField> createState() => _ListingCategoryFieldState();
}

class _ListingCategoryFieldState extends State<ListingCategoryField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );
  final FocusNode _focus = FocusNode();
  List<String> _options = const [];

  @override
  void initState() {
    super.initState();
    widget.suggestions.then((names) {
      if (mounted) _options = names;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: _controller,
      focusNode: _focus,
      optionsBuilder: (value) {
        final query = value.text.trim().toLowerCase();
        return _options
            .where(
              (name) => query.isEmpty || name.toLowerCase().contains(query),
            )
            .take(8);
      },
      onSelected: widget.onChanged,
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return AddProductField(
          label: widget.label,
          controller: controller,
          focusNode: focusNode,
          hint: widget.hint,
          onChanged: widget.onChanged,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 360),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                children: [
                  for (final option in options)
                    InkWell(
                      onTap: () => onSelected(option),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Text(
                          option,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A weight value with a KG / G unit picker (HungerStation).
class ListingWeightField extends StatefulWidget {
  const ListingWeightField({
    super.key,
    required this.label,
    required this.initial,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final HsWeight? initial;
  final ValueChanged<HsWeight?> onChanged;
  final String? hint;

  @override
  State<ListingWeightField> createState() => _ListingWeightFieldState();
}

class _ListingWeightFieldState extends State<ListingWeightField> {
  late double? _value = widget.initial?.value;
  late HsWeightUnit _unit = widget.initial?.unit ?? HsWeightUnit.kg;

  void _report() =>
      widget.onChanged(_value == null ? null : HsWeight(_value!, _unit));

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: ListingNumberField(
            label: widget.label,
            initial: _value,
            hint: widget.hint,
            onChanged: (value) {
              _value = value?.toDouble();
              _report();
            },
          ),
        ),
        const SizedBox(width: 8),
        SegmentedButton<HsWeightUnit>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: [
            for (final unit in HsWeightUnit.values)
              ButtonSegment(value: unit, label: Text(unit.wire)),
          ],
          selected: {_unit},
          onSelectionChanged: (selection) {
            setState(() => _unit = selection.first);
            _report();
          },
        ),
      ],
    );
  }
}

/// Two fields side by side.
class ListingPair extends StatelessWidget {
  const ListingPair(this.first, this.second, {super.key});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 10),
        Expanded(child: second),
      ],
    );
  }
}
