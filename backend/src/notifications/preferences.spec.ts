import { PREFERENCE_KEYS, preferenceFor, readPreferences } from './preferences.js';

describe('notification preferences', () => {
  it('defaults every switch to on and ignores junk', () => {
    expect(readPreferences(null)).toEqual(Object.fromEntries(PREFERENCE_KEYS.map((k) => [k, true])));
    const prefs = readPreferences({ announcements: false, push: 'no', unknown: false });
    expect(prefs.announcements).toBe(false);
    expect(prefs.push).toBe(true); // not a boolean → default
    expect('unknown' in prefs).toBe(false);
  });

  it('maps each notification type to its switch', () => {
    expect(preferenceFor('due_reminder')).toBe('paymentReminder');
    expect(preferenceFor('poll')).toBe('announcements');
    expect(preferenceFor('alert')).toBe('emergencyAlerts');
    expect(preferenceFor('tenancy')).toBeNull(); // always delivered
  });
});
