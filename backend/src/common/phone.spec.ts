import { maskPhone, normalizeIndianMobile } from './phone.js';

describe('normalizeIndianMobile', () => {
  it.each(['9876543210', '98765 43210', '+91 98765-43210', '+919876543210', '919876543210', '09876543210', '(98765) 43210'])(
    'accepts %s',
    (input) => expect(normalizeIndianMobile(input)).toBe('+919876543210'),
  );

  it.each(['5876543210', '987654321', '98765432100', 'abcdefghij', '+1 9876543210', ''])('rejects %s', (input) =>
    expect(normalizeIndianMobile(input)).toBeNull(),
  );
});

it('masks all but the last four digits', () => {
  expect(maskPhone('+919876543210')).toBe('+91 ••••••3210');
});
