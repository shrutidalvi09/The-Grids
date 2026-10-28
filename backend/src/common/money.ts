/** "₹2,500" (Indian digit grouping) from paise. */
export const inr = (paise: number) => `₹${new Intl.NumberFormat('en-IN').format(paise / 100)}`;
