/**
 * Notification preferences, one switch per kind of update (matches the
 * Notification Preferences screen). Everything is on by default.
 */
export const PREFERENCE_KEYS = [
  'paymentReminder',
  'paymentSuccess',
  'maintenanceDue',
  'announcements',
  'eventsNotices',
  'emergencyAlerts',
  'complaintUpdates',
  'visitorArrival',
  'packageDelivery',
  'staffAttendance',
  /** Off = keep notifications in the app's list but don't push them to the phone. */
  'push',
] as const;

export type PreferenceKey = (typeof PREFERENCE_KEYS)[number];
export type NotificationPreferences = Record<PreferenceKey, boolean>;

/** Which switch controls each notification type. */
const TYPE_TO_PREFERENCE: Record<string, PreferenceKey> = {
  due_reminder: 'paymentReminder',
  payment: 'paymentSuccess',
  due: 'maintenanceDue',
  poll: 'announcements',
  announcement: 'announcements',
  notice: 'eventsNotices',
  event: 'eventsNotices',
  alert: 'emergencyAlerts',
  complaint: 'complaintUpdates',
  visitor: 'visitorArrival',
  parcel: 'packageDelivery',
  staff: 'staffAttendance',
};

export function preferenceFor(type: string): PreferenceKey | null {
  return TYPE_TO_PREFERENCE[type] ?? null;
}

/** Stored JSON (possibly partial or from an older version) → full set. */
export function readPreferences(stored: unknown): NotificationPreferences {
  const source = stored && typeof stored === 'object' ? (stored as Record<string, unknown>) : {};
  return Object.fromEntries(
    PREFERENCE_KEYS.map((key) => [key, typeof source[key] === 'boolean' ? source[key] : true]),
  ) as NotificationPreferences;
}
