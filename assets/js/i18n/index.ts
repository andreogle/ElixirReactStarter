import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import { go } from '../result';
import en from './locales/en';
import es from './locales/es';

const initializeI18n = () => {
  return i18n.use(initReactI18next).init({
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
};

void go(initializeI18n).then(([error]) => {
  if (error) console.error('Failed to initialize translations:', error);
});

export default i18n;
