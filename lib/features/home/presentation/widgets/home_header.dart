import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/domain/session.dart';
import '../../domain/home_models.dart';

/// "Good morning, Shruti!", flat, today's date and the weather.
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({super.key, required this.session, this.weather, this.now});

  final AppSession session;
  final Weather? weather;

  /// Injectable for tests.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final time = now ?? DateTime.now();
    final greeting = switch (time.hour) {
      < 12 => l10n.greetingMorning(session.firstName),
      < 17 => l10n.greetingAfternoon(session.firstName),
      _ => l10n.greetingEvening(session.firstName),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(greeting, style: theme.textTheme.headlineSmall)),
        if (session.flatLabel != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(session.flatLabel!, style: theme.textTheme.titleMedium),
        ],
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xl,
          runSpacing: AppSpacing.xs,
          children: [
            _Fact(icon: Icons.calendar_month_rounded, text: formatDate(context, time)),
            if (weather != null)
              Semantics(
                label: l10n.weatherNow(weather!.temperatureC, _condition(l10n, weather!.code)),
                excludeSemantics: true,
                child: _Fact(icon: _icon(weather!.code), text: '${weather!.temperatureC}°C'),
              ),
          ],
        ),
      ],
    );
  }

  static IconData _icon(int code) => switch (code) {
        0 => Icons.wb_sunny_rounded,
        1 || 2 => Icons.wb_cloudy_rounded,
        3 => Icons.cloud_rounded,
        45 || 48 => Icons.foggy,
        >= 71 && <= 77 || 85 || 86 => Icons.ac_unit_rounded,
        >= 95 => Icons.thunderstorm_rounded,
        >= 51 => Icons.umbrella_rounded,
        _ => Icons.wb_cloudy_rounded,
      };

  static String _condition(AppLocalizations l10n, int code) => switch (code) {
        0 => l10n.weatherClear,
        1 || 2 || 3 => l10n.weatherCloudy,
        45 || 48 => l10n.weatherFog,
        >= 71 && <= 77 || 85 || 86 => l10n.weatherSnow,
        >= 95 => l10n.weatherStorm,
        >= 51 => l10n.weatherRain,
        _ => l10n.weatherCloudy,
      };
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: GridsColors.of(context).slate),
        const SizedBox(width: AppSpacing.xs + 2),
        Text(text, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}

/// Dark pill banner for the society's current alert ("Water supply off…").
class AlertBanner extends StatelessWidget {
  const AlertBanner({super.key, required this.alert});

  final HomeAlert alert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Same dark slate in both themes; white and light orange both pass
    // WCAG AA contrast on it.
    return Semantics(
      container: true,
      label: '${context.l10n.alertLabel}: ${alert.title}. ${alert.body}',
      excludeSemantics: true,
      child: Container(
        decoration: const BoxDecoration(color: AppColors.slate, borderRadius: BorderRadius.all(Radius.circular(32))),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 40),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alert.title, style: theme.textTheme.titleMedium?.copyWith(color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(
                    alert.body,
                    style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFFFFCC80)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
