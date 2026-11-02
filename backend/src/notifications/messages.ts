import { inr } from '../common/money.js';

/**
 * Notification texts the server writes itself, in each of the app's eight
 * languages. (Notices and club announcements are written by admins and sent
 * as typed.) The recipient's `User.language` picks the version.
 */
export const LANGUAGES = ['en', 'hi', 'mr', 'gu', 'ta', 'te', 'kn', 'bn'] as const;
export type Lang = (typeof LANGUAGES)[number];

export type Message =
  | { key: 'poll_new'; question: string }
  | { key: 'due'; dueType: 'RENT' | 'MAINTENANCE'; amountPaise: number; period: string; dueDate: Date; timezone: string }
  | { key: 'due_reminder'; amountPaise: number; periods: string[] }
  | { key: 'payment'; dueType: 'RENT' | 'MAINTENANCE'; amountPaise: number; period: string; receiptNo: string }
  | { key: 'tenancy'; owner: string; flat: string; amountPaise: number }
  | { key: 'complaint'; title: string; status: 'OPEN' | 'IN_PROGRESS' | 'RESOLVED' }
  | { key: 'visitor_arrived'; name: string }
  | { key: 'visitor_at_gate'; name: string }
  | { key: 'event_new'; title: string; startsAt: Date; timezone: string }
  | { key: 'visitor_approval'; name: string }
  | { key: 'visitor_decision'; name: string; flat: string; allowed: boolean }
  | { key: 'staff_arrived'; name: string }
  | { key: 'sos'; name: string; flat: string | null };

type Rendered = { title: string; body: string };

const LOCALES: Record<Lang, string> = {
  en: 'en-IN',
  hi: 'hi-IN',
  mr: 'mr-IN',
  gu: 'gu-IN',
  ta: 'ta-IN',
  te: 'te-IN',
  kn: 'kn-IN',
  bn: 'bn-IN',
};

/** Locale-aware date helpers (Latin digits, to match the ₹ amounts). */
function formatters(lang: Lang) {
  const locale = LOCALES[lang];
  const month = (period: string) => {
    const [y, m] = period.split('-').map(Number);
    return new Intl.DateTimeFormat(locale, { month: 'long', year: 'numeric', timeZone: 'UTC', numberingSystem: 'latn' }).format(
      new Date(Date.UTC(y, m - 1, 1)),
    );
  };
  const date = (d: Date, timeZone: string) =>
    new Intl.DateTimeFormat(locale, { day: 'numeric', month: 'short', timeZone, numberingSystem: 'latn' }).format(d);
  const dateTime = (d: Date, timeZone: string) =>
    new Intl.DateTimeFormat(locale, {
      weekday: 'short',
      day: 'numeric',
      month: 'short',
      hour: 'numeric',
      minute: '2-digit',
      timeZone,
      numberingSystem: 'latn',
    }).format(d);
  const list = (items: string[]) => new Intl.ListFormat(locale, { type: 'conjunction' }).format(items);
  return { month, date, dateTime, list };
}

type F = ReturnType<typeof formatters>;
type Templates = { [K in Message['key']]: Record<Lang, (m: Extract<Message, { key: K }>, f: F) => Rendered> };

const T: Templates = {
  poll_new: {
    en: (m) => ({ title: 'New poll', body: `${m.question} Cast your vote.` }),
    hi: (m) => ({ title: 'नया मतदान', body: `${m.question} अपना वोट दें।` }),
    mr: (m) => ({ title: 'नवीन मतदान', body: `${m.question} तुमचे मत द्या.` }),
    gu: (m) => ({ title: 'નવું મતદાન', body: `${m.question} તમારો મત આપો.` }),
    ta: (m) => ({ title: 'புதிய வாக்கெடுப்பு', body: `${m.question} உங்கள் வாக்கைச் செலுத்துங்கள்.` }),
    te: (m) => ({ title: 'కొత్త పోల్', body: `${m.question} మీ ఓటు వేయండి.` }),
    kn: (m) => ({ title: 'ಹೊಸ ಮತದಾನ', body: `${m.question} ನಿಮ್ಮ ಮತ ಹಾಕಿ.` }),
    bn: (m) => ({ title: 'নতুন পোল', body: `${m.question} আপনার ভোট দিন।` }),
  },
  due: {
    en: (m, f) => ({
      title: m.dueType === 'RENT' ? 'Rent due' : 'Maintenance due',
      body: `${inr(m.amountPaise)} for ${f.month(m.period)} is due on ${f.date(m.dueDate, m.timezone)}.`,
    }),
    hi: (m, f) => ({
      title: m.dueType === 'RENT' ? 'किराया बकाया' : 'रखरखाव बकाया',
      body: `${f.month(m.period)} के ${inr(m.amountPaise)} ${f.date(m.dueDate, m.timezone)} तक देय हैं।`,
    }),
    mr: (m, f) => ({
      title: m.dueType === 'RENT' ? 'भाडे देय' : 'देखभाल शुल्क देय',
      body: `${f.month(m.period)} चे ${inr(m.amountPaise)} ${f.date(m.dueDate, m.timezone)} पर्यंत भरायचे आहेत.`,
    }),
    gu: (m, f) => ({
      title: m.dueType === 'RENT' ? 'ભાડું બાકી' : 'મેન્ટેનન્સ બાકી',
      body: `${f.month(m.period)}ના ${inr(m.amountPaise)} ${f.date(m.dueDate, m.timezone)} સુધીમાં ચૂકવવાના છે.`,
    }),
    ta: (m, f) => ({
      title: m.dueType === 'RENT' ? 'வாடகை நிலுவை' : 'பராமரிப்புக் கட்டணம் நிலுவை',
      body: `${f.month(m.period)}க்கான ${inr(m.amountPaise)} ${f.date(m.dueDate, m.timezone)} அன்று செலுத்த வேண்டும்.`,
    }),
    te: (m, f) => ({
      title: m.dueType === 'RENT' ? 'అద్దె బకాయి' : 'నిర్వహణ బకాయి',
      body: `${f.month(m.period)}కి ${inr(m.amountPaise)} ${f.date(m.dueDate, m.timezone)} నాటికి చెల్లించాలి.`,
    }),
    kn: (m, f) => ({
      title: m.dueType === 'RENT' ? 'ಬಾಡಿಗೆ ಬಾಕಿ' : 'ನಿರ್ವಹಣೆ ಬಾಕಿ',
      body: `${f.month(m.period)}ರ ${inr(m.amountPaise)} ${f.date(m.dueDate, m.timezone)} ರೊಳಗೆ ಪಾವತಿಸಬೇಕು.`,
    }),
    bn: (m, f) => ({
      title: m.dueType === 'RENT' ? 'ভাড়া বকেয়া' : 'রক্ষণাবেক্ষণ বকেয়া',
      body: `${f.month(m.period)}-এর ${inr(m.amountPaise)} ${f.date(m.dueDate, m.timezone)}-এর মধ্যে দিতে হবে।`,
    }),
  },
  due_reminder: {
    en: (m, f) => ({
      title: 'Maintenance reminder',
      body: `Your maintenance of ${inr(m.amountPaise)} for ${f.list(m.periods.map(f.month))} is pending. Please pay from the Maintenance tab.`,
    }),
    hi: (m, f) => ({
      title: 'रखरखाव रिमाइंडर',
      body: `${f.list(m.periods.map(f.month))} का आपका ${inr(m.amountPaise)} का रखरखाव बकाया है। कृपया रखरखाव टैब से भुगतान करें।`,
    }),
    mr: (m, f) => ({
      title: 'देखभाल शुल्क स्मरण',
      body: `${f.list(m.periods.map(f.month))} चे तुमचे ${inr(m.amountPaise)} देखभाल शुल्क थकीत आहे. कृपया देखभाल टॅबमधून भरा.`,
    }),
    gu: (m, f) => ({
      title: 'મેન્ટેનન્સ રિમાઇન્ડર',
      body: `${f.list(m.periods.map(f.month))}નું તમારું ${inr(m.amountPaise)}નું મેન્ટેનન્સ બાકી છે. કૃપા કરી મેન્ટેનન્સ ટૅબમાંથી ચૂકવો.`,
    }),
    ta: (m, f) => ({
      title: 'பராமரிப்பு நினைவூட்டல்',
      body: `${f.list(m.periods.map(f.month))}க்கான உங்கள் ${inr(m.amountPaise)} பராமரிப்புக் கட்டணம் நிலுவையில் உள்ளது. பராமரிப்புத் தாவலில் செலுத்துங்கள்.`,
    }),
    te: (m, f) => ({
      title: 'నిర్వహణ రిమైండర్',
      body: `${f.list(m.periods.map(f.month))}కి మీ ${inr(m.amountPaise)} నిర్వహణ బకాయి ఉంది. దయచేసి నిర్వహణ ట్యాబ్ నుండి చెల్లించండి.`,
    }),
    kn: (m, f) => ({
      title: 'ನಿರ್ವಹಣೆ ಜ್ಞಾಪನೆ',
      body: `${f.list(m.periods.map(f.month))}ರ ನಿಮ್ಮ ${inr(m.amountPaise)} ನಿರ್ವಹಣೆ ಶುಲ್ಕ ಬಾಕಿ ಇದೆ. ದಯವಿಟ್ಟು ನಿರ್ವಹಣೆ ಟ್ಯಾಬ್‌ನಿಂದ ಪಾವತಿಸಿ.`,
    }),
    bn: (m, f) => ({
      title: 'রক্ষণাবেক্ষণ রিমাইন্ডার',
      body: `${f.list(m.periods.map(f.month))}-এর আপনার ${inr(m.amountPaise)} রক্ষণাবেক্ষণ বকেয়া আছে। অনুগ্রহ করে রক্ষণাবেক্ষণ ট্যাব থেকে দিন।`,
    }),
  },
  payment: {
    en: (m, f) => ({
      title: 'Payment received',
      body: `${inr(m.amountPaise)} for ${m.dueType === 'RENT' ? 'rent' : 'maintenance'}, ${f.month(m.period)}. Receipt ${m.receiptNo}.`,
    }),
    hi: (m, f) => ({
      title: 'भुगतान प्राप्त हुआ',
      body: `${f.month(m.period)} के ${m.dueType === 'RENT' ? 'किराए' : 'रखरखाव'} के लिए ${inr(m.amountPaise)}। रसीद ${m.receiptNo}।`,
    }),
    mr: (m, f) => ({
      title: 'पेमेंट मिळाले',
      body: `${f.month(m.period)} च्या ${m.dueType === 'RENT' ? 'भाड्या' : 'देखभाल शुल्का'}साठी ${inr(m.amountPaise)}. पावती ${m.receiptNo}.`,
    }),
    gu: (m, f) => ({
      title: 'ચુકવણી મળી',
      body: `${f.month(m.period)}ના ${m.dueType === 'RENT' ? 'ભાડા' : 'મેન્ટેનન્સ'} માટે ${inr(m.amountPaise)}. રસીદ ${m.receiptNo}.`,
    }),
    ta: (m, f) => ({
      title: 'கட்டணம் பெறப்பட்டது',
      body: `${f.month(m.period)} ${m.dueType === 'RENT' ? 'வாடகை' : 'பராமரிப்பு'}க்கு ${inr(m.amountPaise)}. ரசீது ${m.receiptNo}.`,
    }),
    te: (m, f) => ({
      title: 'చెల్లింపు అందింది',
      body: `${f.month(m.period)} ${m.dueType === 'RENT' ? 'అద్దె' : 'నిర్వహణ'} కోసం ${inr(m.amountPaise)}. రసీదు ${m.receiptNo}.`,
    }),
    kn: (m, f) => ({
      title: 'ಪಾವತಿ ಸ್ವೀಕರಿಸಲಾಗಿದೆ',
      body: `${f.month(m.period)} ${m.dueType === 'RENT' ? 'ಬಾಡಿಗೆ' : 'ನಿರ್ವಹಣೆ'}ಗೆ ${inr(m.amountPaise)}. ರಸೀದಿ ${m.receiptNo}.`,
    }),
    bn: (m, f) => ({
      title: 'পেমেন্ট পাওয়া গেছে',
      body: `${f.month(m.period)}-এর ${m.dueType === 'RENT' ? 'ভাড়া' : 'রক্ষণাবেক্ষণ'} বাবদ ${inr(m.amountPaise)}। রসিদ ${m.receiptNo}।`,
    }),
  },
  tenancy: {
    en: (m) => ({ title: 'Welcome to your new home', body: `${m.owner} added you as the tenant of ${m.flat}. Rent: ${inr(m.amountPaise)} a month.` }),
    hi: (m) => ({ title: 'आपके नए घर में स्वागत है', body: `${m.owner} ने आपको ${m.flat} का किरायेदार जोड़ा है। किराया: ${inr(m.amountPaise)} प्रति माह।` }),
    mr: (m) => ({ title: 'तुमच्या नवीन घरात स्वागत', body: `${m.owner} यांनी तुम्हाला ${m.flat} चे भाडेकरू म्हणून जोडले आहे. भाडे: दरमहा ${inr(m.amountPaise)}.` }),
    gu: (m) => ({ title: 'તમારા નવા ઘરમાં સ્વાગત છે', body: `${m.owner}એ તમને ${m.flat}ના ભાડૂઆત તરીકે ઉમેર્યા છે. ભાડું: દર મહિને ${inr(m.amountPaise)}.` }),
    ta: (m) => ({ title: 'உங்கள் புதிய வீட்டிற்கு வரவேற்கிறோம்', body: `${m.owner} உங்களை ${m.flat} வாடகைதாரராகச் சேர்த்துள்ளார். வாடகை: மாதம் ${inr(m.amountPaise)}.` }),
    te: (m) => ({ title: 'మీ కొత్త ఇంటికి స్వాగతం', body: `${m.owner} మిమ్మల్ని ${m.flat} అద్దెదారుగా జోడించారు. అద్దె: నెలకు ${inr(m.amountPaise)}.` }),
    kn: (m) => ({ title: 'ನಿಮ್ಮ ಹೊಸ ಮನೆಗೆ ಸ್ವಾಗತ', body: `${m.owner} ಅವರು ನಿಮ್ಮನ್ನು ${m.flat} ನ ಬಾಡಿಗೆದಾರರಾಗಿ ಸೇರಿಸಿದ್ದಾರೆ. ಬಾಡಿಗೆ: ತಿಂಗಳಿಗೆ ${inr(m.amountPaise)}.` }),
    bn: (m) => ({ title: 'আপনার নতুন বাড়িতে স্বাগত', body: `${m.owner} আপনাকে ${m.flat}-এর ভাড়াটে হিসেবে যোগ করেছেন। ভাড়া: মাসে ${inr(m.amountPaise)}।` }),
  },
  complaint: {
    en: (m) => ({
      title: 'Complaint update',
      body: `"${m.title}" is ${{ OPEN: 'reopened', IN_PROGRESS: 'in progress', RESOLVED: 'resolved' }[m.status]}.`,
    }),
    hi: (m) => ({
      title: 'शिकायत अपडेट',
      body: `"${m.title}" — ${{ OPEN: 'फिर से खोली गई', IN_PROGRESS: 'प्रगति पर', RESOLVED: 'हल हो गई' }[m.status]}।`,
    }),
    mr: (m) => ({
      title: 'तक्रार अपडेट',
      body: `"${m.title}" — ${{ OPEN: 'पुन्हा उघडली', IN_PROGRESS: 'प्रगतीपथावर', RESOLVED: 'सोडवली' }[m.status]}.`,
    }),
    gu: (m) => ({
      title: 'ફરિયાદ અપડેટ',
      body: `"${m.title}" — ${{ OPEN: 'ફરી ખોલી', IN_PROGRESS: 'પ્રગતિમાં', RESOLVED: 'ઉકેલાઈ' }[m.status]}.`,
    }),
    ta: (m) => ({
      title: 'புகார் புதுப்பிப்பு',
      body: `"${m.title}" — ${{ OPEN: 'மீண்டும் திறக்கப்பட்டது', IN_PROGRESS: 'நடைபெறுகிறது', RESOLVED: 'தீர்க்கப்பட்டது' }[m.status]}.`,
    }),
    te: (m) => ({
      title: 'ఫిర్యాదు అప్‌డేట్',
      body: `"${m.title}" — ${{ OPEN: 'మళ్లీ తెరవబడింది', IN_PROGRESS: 'పురోగతిలో ఉంది', RESOLVED: 'పరిష్కరించబడింది' }[m.status]}.`,
    }),
    kn: (m) => ({
      title: 'ದೂರು ಅಪ್‌ಡೇಟ್',
      body: `"${m.title}" — ${{ OPEN: 'ಮತ್ತೆ ತೆರೆಯಲಾಗಿದೆ', IN_PROGRESS: 'ಪ್ರಗತಿಯಲ್ಲಿದೆ', RESOLVED: 'ಪರಿಹರಿಸಲಾಗಿದೆ' }[m.status]}.`,
    }),
    bn: (m) => ({
      title: 'অভিযোগের আপডেট',
      body: `"${m.title}" — ${{ OPEN: 'আবার খোলা হয়েছে', IN_PROGRESS: 'চলছে', RESOLVED: 'সমাধান হয়েছে' }[m.status]}।`,
    }),
  },
  visitor_arrived: {
    en: (m) => ({ title: 'Visitor arrived', body: `${m.name} has checked in at the gate.` }),
    hi: (m) => ({ title: 'मेहमान आ गए', body: `${m.name} गेट पर चेक-इन कर चुके हैं।` }),
    mr: (m) => ({ title: 'पाहुणे आले', body: `${m.name} यांनी गेटवर चेक-इन केले.` }),
    gu: (m) => ({ title: 'મુલાકાતી આવ્યા', body: `${m.name}એ ગેટ પર ચેક-ઇન કર્યું.` }),
    ta: (m) => ({ title: 'பார்வையாளர் வந்துள்ளார்', body: `${m.name} வாயிலில் உள்நுழைந்துள்ளார்.` }),
    te: (m) => ({ title: 'సందర్శకుడు వచ్చారు', body: `${m.name} గేట్ వద్ద చెక్-ఇన్ అయ్యారు.` }),
    kn: (m) => ({ title: 'ಸಂದರ್ಶಕರು ಬಂದಿದ್ದಾರೆ', body: `${m.name} ಗೇಟ್‌ನಲ್ಲಿ ಚೆಕ್-ಇನ್ ಆಗಿದ್ದಾರೆ.` }),
    bn: (m) => ({ title: 'অতিথি এসেছেন', body: `${m.name} গেটে চেক-ইন করেছেন।` }),
  },
  visitor_at_gate: {
    en: (m) => ({ title: 'Parcel at security', body: `A parcel from ${m.name} is waiting at the gate.` }),
    hi: (m) => ({ title: 'पार्सल सिक्योरिटी पर', body: `${m.name} का पार्सल गेट पर रखा है।` }),
    mr: (m) => ({ title: 'पार्सल सिक्युरिटीकडे', body: `${m.name} चे पार्सल गेटवर ठेवले आहे.` }),
    gu: (m) => ({ title: 'પાર્સલ સિક્યોરિટી પર', body: `${m.name}નું પાર્સલ ગેટ પર રાખ્યું છે.` }),
    ta: (m) => ({ title: 'பார்சல் பாதுகாவலரிடம்', body: `${m.name} இலிருந்து பார்சல் வாயிலில் காத்திருக்கிறது.` }),
    te: (m) => ({ title: 'పార్శిల్ సెక్యూరిటీ వద్ద', body: `${m.name} నుండి పార్శిల్ గేట్ వద్ద ఉంది.` }),
    kn: (m) => ({ title: 'ಪಾರ್ಸೆಲ್ ಭದ್ರತೆಯಲ್ಲಿ', body: `${m.name} ಇಂದ ಪಾರ್ಸೆಲ್ ಗೇಟ್‌ನಲ್ಲಿ ಕಾಯುತ್ತಿದೆ.` }),
    bn: (m) => ({ title: 'পার্সেল নিরাপত্তায়', body: `${m.name}-এর পার্সেল গেটে অপেক্ষা করছে।` }),
  },
  event_new: {
    en: (m, f) => ({ title: 'New event', body: `${m.title} on ${f.dateTime(m.startsAt, m.timezone)}.` }),
    hi: (m, f) => ({ title: 'नया कार्यक्रम', body: `${m.title} — ${f.dateTime(m.startsAt, m.timezone)}।` }),
    mr: (m, f) => ({ title: 'नवीन कार्यक्रम', body: `${m.title} — ${f.dateTime(m.startsAt, m.timezone)}.` }),
    gu: (m, f) => ({ title: 'નવો કાર્યક્રમ', body: `${m.title} — ${f.dateTime(m.startsAt, m.timezone)}.` }),
    ta: (m, f) => ({ title: 'புதிய நிகழ்வு', body: `${m.title} — ${f.dateTime(m.startsAt, m.timezone)}.` }),
    te: (m, f) => ({ title: 'కొత్త కార్యక్రమం', body: `${m.title} — ${f.dateTime(m.startsAt, m.timezone)}.` }),
    kn: (m, f) => ({ title: 'ಹೊಸ ಕಾರ್ಯಕ್ರಮ', body: `${m.title} — ${f.dateTime(m.startsAt, m.timezone)}.` }),
    bn: (m, f) => ({ title: 'নতুন অনুষ্ঠান', body: `${m.title} — ${f.dateTime(m.startsAt, m.timezone)}।` }),
  },
  visitor_approval: {
    en: (m) => ({ title: 'Visitor at the gate', body: `${m.name} is at the gate. Allow or deny?` }),
    hi: (m) => ({ title: 'गेट पर मेहमान', body: `${m.name} गेट पर हैं। अंदर आने दें या मना करें?` }),
    mr: (m) => ({ title: 'गेटवर पाहुणे', body: `${m.name} गेटवर आहेत. आत येऊ द्यायचे की नाकारायचे?` }),
    gu: (m) => ({ title: 'ગેટ પર મુલાકાતી', body: `${m.name} ગેટ પર છે. અંદર આવવા દેવા કે ના પાડવી?` }),
    ta: (m) => ({ title: 'வாயிலில் பார்வையாளர்', body: `${m.name} வாயிலில் இருக்கிறார். அனுமதிக்கவா மறுக்கவா?` }),
    te: (m) => ({ title: 'గేట్ వద్ద సందర్శకుడు', body: `${m.name} గేట్ వద్ద ఉన్నారు. అనుమతించాలా తిరస్కరించాలా?` }),
    kn: (m) => ({ title: 'ಗೇಟ್‌ನಲ್ಲಿ ಸಂದರ್ಶಕರು', body: `${m.name} ಗೇಟ್‌ನಲ್ಲಿದ್ದಾರೆ. ಅನುಮತಿಸಬೇಕೇ ನಿರಾಕರಿಸಬೇಕೇ?` }),
    bn: (m) => ({ title: 'গেটে অতিথি', body: `${m.name} গেটে আছেন। ঢুকতে দেবেন না ফিরিয়ে দেবেন?` }),
  },
  visitor_decision: {
    en: (m) => ({ title: m.allowed ? 'Visitor allowed' : 'Visitor denied', body: `${m.flat}: ${m.name}` }),
    hi: (m) => ({ title: m.allowed ? 'मेहमान को अनुमति' : 'मेहमान को मना', body: `${m.flat}: ${m.name}` }),
    mr: (m) => ({ title: m.allowed ? 'पाहुण्यांना परवानगी' : 'पाहुण्यांना नकार', body: `${m.flat}: ${m.name}` }),
    gu: (m) => ({ title: m.allowed ? 'મુલાકાતીને મંજૂરી' : 'મુલાકાતીને ના', body: `${m.flat}: ${m.name}` }),
    ta: (m) => ({ title: m.allowed ? 'பார்வையாளர் அனுமதிக்கப்பட்டார்' : 'பார்வையாளர் மறுக்கப்பட்டார்', body: `${m.flat}: ${m.name}` }),
    te: (m) => ({ title: m.allowed ? 'సందర్శకుడికి అనుమతి' : 'సందర్శకుడు తిరస్కరించబడ్డారు', body: `${m.flat}: ${m.name}` }),
    kn: (m) => ({ title: m.allowed ? 'ಸಂದರ್ಶಕರಿಗೆ ಅನುಮತಿ' : 'ಸಂದರ್ಶಕರಿಗೆ ನಿರಾಕರಣೆ', body: `${m.flat}: ${m.name}` }),
    bn: (m) => ({ title: m.allowed ? 'অতিথিকে অনুমতি' : 'অতিথিকে ফেরানো হয়েছে', body: `${m.flat}: ${m.name}` }),
  },
  staff_arrived: {
    en: (m) => ({ title: 'Daily help arrived', body: `${m.name} has checked in at the gate.` }),
    hi: (m) => ({ title: 'घरेलू सहायक आ गए', body: `${m.name} गेट पर चेक-इन कर चुके हैं।` }),
    mr: (m) => ({ title: 'घरकाम मदतनीस आले', body: `${m.name} यांनी गेटवर चेक-इन केले.` }),
    gu: (m) => ({ title: 'ઘરકામ સહાયક આવ્યા', body: `${m.name}એ ગેટ પર ચેક-ઇન કર્યું.` }),
    ta: (m) => ({ title: 'வீட்டு உதவியாளர் வந்துள்ளார்', body: `${m.name} வாயிலில் உள்நுழைந்துள்ளார்.` }),
    te: (m) => ({ title: 'ఇంటి సహాయకులు వచ్చారు', body: `${m.name} గేట్ వద్ద చెక్-ఇన్ అయ్యారు.` }),
    kn: (m) => ({ title: 'ಮನೆಗೆಲಸದವರು ಬಂದಿದ್ದಾರೆ', body: `${m.name} ಗೇಟ್‌ನಲ್ಲಿ ಚೆಕ್-ಇನ್ ಆಗಿದ್ದಾರೆ.` }),
    bn: (m) => ({ title: 'গৃহকর্মী এসেছেন', body: `${m.name} গেটে চেক-ইন করেছেন।` }),
  },
  sos: {
    en: (m) => ({ title: 'SOS: emergency', body: `${m.name}${m.flat ? ` (${m.flat})` : ''} needs help now.` }),
    hi: (m) => ({ title: 'SOS: आपातकाल', body: `${m.name}${m.flat ? ` (${m.flat})` : ''} को तुरंत मदद चाहिए।` }),
    mr: (m) => ({ title: 'SOS: आणीबाणी', body: `${m.name}${m.flat ? ` (${m.flat})` : ''} यांना तातडीने मदत हवी आहे.` }),
    gu: (m) => ({ title: 'SOS: કટોકટી', body: `${m.name}${m.flat ? ` (${m.flat})` : ''}ને તરત મદદ જોઈએ છે.` }),
    ta: (m) => ({ title: 'SOS: அவசரநிலை', body: `${m.name}${m.flat ? ` (${m.flat})` : ''} உடனடியாக உதவி தேவை.` }),
    te: (m) => ({ title: 'SOS: అత్యవసరం', body: `${m.name}${m.flat ? ` (${m.flat})` : ''}కి వెంటనే సహాయం కావాలి.` }),
    kn: (m) => ({ title: 'SOS: ತುರ್ತು', body: `${m.name}${m.flat ? ` (${m.flat})` : ''} ಅವರಿಗೆ ತಕ್ಷಣ ಸಹಾಯ ಬೇಕು.` }),
    bn: (m) => ({ title: 'SOS: জরুরি অবস্থা', body: `${m.name}${m.flat ? ` (${m.flat})` : ''}-এর এখনই সাহায্য দরকার।` }),
  },
};

export function asLang(value: string | null | undefined): Lang {
  return (LANGUAGES as readonly string[]).includes(value ?? '') ? (value as Lang) : 'en';
}

/** The notification's title and body in [lang] (English if unknown). */
export function renderMessage(message: Message, lang: string): Rendered {
  const l = asLang(lang);
  const template = T[message.key][l] as (m: Message, f: F) => Rendered;
  return template(message, formatters(l));
}
