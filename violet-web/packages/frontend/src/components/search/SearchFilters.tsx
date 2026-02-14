import styles from './SearchFilters.module.css';

interface SearchFiltersProps {
  language: string;
  onLanguageChange: (lang: string) => void;
}

const languages = ['all', 'korean', 'english', 'japanese', 'chinese'];

export function SearchFilters({ language, onLanguageChange }: SearchFiltersProps) {
  return (
    <div className={styles.filters}>
      <select
        className={styles.select}
        value={language}
        onChange={(e) => onLanguageChange(e.target.value)}
      >
        {languages.map((lang) => (
          <option key={lang} value={lang}>
            {lang === 'all' ? 'All Languages' : lang.charAt(0).toUpperCase() + lang.slice(1)}
          </option>
        ))}
      </select>
    </div>
  );
}
