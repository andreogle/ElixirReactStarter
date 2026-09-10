import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import { go } from '../result.ts';
import en from './locales/en.ts';
import es from './locales/es.ts';

const initializeI18n = () =>
  i18n.use(initReactI18next).init({
    resources: {
      en: { translation: en },
      es: { translation: es },
    },
    lng: 'en',
    fallbackLng: 'en',
    interpolation: {
      escapeValue: false,
    },
  });

void go(initializeI18n).then(([error]) => {
  if (error) {
    console.error('Failed to initialize translations:', error);
  }
});
