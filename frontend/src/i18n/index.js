import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import LanguageDetector from 'i18next-browser-languagedetector';
import en from './locales/en.json';
import fr from './locales/fr.json';
import rw from './locales/rw.json';

export const SUPPORTED_LOCALES = ['en', 'fr', 'rw'];

i18n
    .use(LanguageDetector)
    .use(initReactI18next)
    .init({
        resources: { en: { translation: en }, fr: { translation: fr }, rw: { translation: rw } },
        fallbackLng: 'en',
        supportedLngs: SUPPORTED_LOCALES,
        interpolation: { escapeValue: false },
    });

export default i18n;
