import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../domain/gate_models.dart';

/// "Maid", "Cook"… in the user's language (the API stores English names).
String helpKindLabel(AppLocalizations l10n, String kind) => switch (kind) {
      'Maid' => l10n.helpMaid,
      'Cook' => l10n.helpCook,
      'Driver' => l10n.helpDriver,
      'Nanny' => l10n.helpNanny,
      'Cleaner' => l10n.helpCleaner,
      _ => l10n.helpOther,
    };

String vehicleTypeLabel(AppLocalizations l10n, VehicleType type) => switch (type) {
      VehicleType.car => l10n.vehicleCar,
      VehicleType.bike => l10n.vehicleBike,
      VehicleType.other => l10n.vehicleOther,
    };

IconData vehicleIcon(VehicleType type) => switch (type) {
      VehicleType.car => Icons.directions_car_rounded,
      VehicleType.bike => Icons.two_wheeler_rounded,
      VehicleType.other => Icons.local_shipping_rounded,
    };
