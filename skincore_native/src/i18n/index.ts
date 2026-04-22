import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import * as Localization from 'expo-localization';
import tr from './tr.json';
import en from './en.json';

const deviceLocale = Localization.getLocales()[0]?.languageCode ?? 'tr';
const supportedLanguage = deviceLocale === 'en' ? 'en' : 'tr';

i18n
  .use(initReactI18next)
  .init({
    resources: {
      tr: { translation: tr },
      en: { translation: en },
    },
    lng: supportedLanguage,
    fallbackLng: 'tr',
    interpolation: {
      escapeValue: false,
    },
    compatibilityJSON: 'v4',
  });

export default i18n;

// Swift LanguageManager karşılığı: dil değiştirme
export function changeLanguage(lang: 'tr' | 'en') {
  i18n.changeLanguage(lang);
}

export function getCurrentLanguage(): 'tr' | 'en' {
  return (i18n.language as 'tr' | 'en') ?? 'tr';
}
