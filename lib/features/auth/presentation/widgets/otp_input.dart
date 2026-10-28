import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Six digit boxes backed by one real text field, so SMS autofill, paste and
/// screen readers all work as for a normal input.
class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    required this.controller,
    required this.semanticLabel,
    this.length = 6,
    this.onCompleted,
    this.hasError = false,
  });

  final TextEditingController controller;
  final String semanticLabel;
  final int length;
  final ValueChanged<String>? onCompleted;
  final bool hasError;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _focus.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focus.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final grids = GridsColors.of(context);
    final text = widget.controller.text;
    final activeIndex = _focus.hasFocus ? text.length.clamp(0, widget.length - 1) : -1;

    return Stack(
      children: [
        ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < widget.length; i++)
                _Box(
                  digit: i < text.length ? text[i] : '',
                  active: i == activeIndex,
                  borderColor: widget.hasError
                      ? scheme.error
                      : i == activeIndex
                          ? scheme.primary
                          : grids.card,
                  fill: grids.card,
                ),
            ],
          ),
        ),
        Positioned.fill(
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            autofocus: true,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(widget.length),
            ],
            showCursor: false,
            enableInteractiveSelection: false,
            style: const TextStyle(color: Colors.transparent, fontSize: 1),
            decoration: InputDecoration(
              filled: false,
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              counterText: '',
              labelText: widget.semanticLabel,
              labelStyle: const TextStyle(color: Colors.transparent, fontSize: 1),
              floatingLabelBehavior: FloatingLabelBehavior.never,
            ),
            onChanged: (value) {
              if (value.length == widget.length) widget.onCompleted?.call(value);
            },
          ),
        ),
      ],
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.digit, required this.active, required this.borderColor, required this.fill});

  final String digit;
  final bool active;
  final Color borderColor;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 46,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: const BorderRadius.all(AppRadii.md),
        border: Border.all(color: borderColor, width: active ? 2 : 1.5),
      ),
      child: Text(digit, style: Theme.of(context).textTheme.headlineSmall),
    );
  }
}
