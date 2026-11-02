import '../../../core/l10n/l10n.dart';

enum UserRole {
  admin('ADMIN'),
  owner('OWNER'),
  tenant('TENANT'),
  guard('GUARD'); // security at the gate

  const UserRole(this.apiName);

  /// The role as the backend spells it.
  final String apiName;

  static UserRole fromApi(String value) =>
      values.firstWhere((role) => role.apiName == value, orElse: () => throw FormatException('Unknown role $value'));

  String label(AppLocalizations l10n) => switch (this) {
        UserRole.admin => l10n.roleAdmin,
        UserRole.owner => l10n.roleOwner,
        UserRole.tenant => l10n.roleTenant,
        UserRole.guard => l10n.roleGuard,
      };

  /// Lives in a flat (owners and tenants).
  bool get isResident => this == UserRole.owner || this == UserRole.tenant;

  /// Works the gate (guards, and admins standing in).
  bool get isGate => this == UserRole.admin || this == UserRole.guard;

  /// Button text on the role picker ("Member (Owner) Login").
  String loginLabel(AppLocalizations l10n) => switch (this) {
        UserRole.admin => l10n.roleLoginAdmin,
        UserRole.owner => l10n.roleLoginOwner,
        UserRole.tenant => l10n.roleLoginTenant,
        UserRole.guard => l10n.roleLoginGuard,
      };
}
