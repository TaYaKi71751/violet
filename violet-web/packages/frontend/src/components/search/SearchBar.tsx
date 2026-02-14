import { useState, type FormEvent } from 'react';
import { useNavigate } from 'react-router';
import { useSearchStore } from '../../stores/search-store';
import styles from './SearchBar.module.css';

export function SearchBar() {
  const [value, setValue] = useState('');
  const navigate = useNavigate();
  const addRecentSearch = useSearchStore((s) => s.addRecentSearch);

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault();
    const q = value.trim();
    if (!q) return;
    addRecentSearch(q);
    navigate(`/search?q=${encodeURIComponent(q)}`);
  };

  return (
    <form className={styles.form} onSubmit={handleSubmit}>
      <input
        className={styles.input}
        type="text"
        value={value}
        onChange={(e) => setValue(e.target.value)}
        placeholder="Search... (e.g. artist:name, tag:name)"
      />
    </form>
  );
}
