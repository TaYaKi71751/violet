import { useState, useRef, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router';
import type { SearchBarRef } from '../components/search/SearchBar';
import type { TagChipData } from './useArticleTagSummary';
import { getLocalSuggestions } from './useLocalSuggestions';
import type { TagEntry } from '@violet-web/shared';

interface UseLocalSearchStateOptions {
  basePath: string;
  tagSummary: TagChipData[];
  onReset?: () => void;
}

export function useLocalSearchState({ basePath, tagSummary, onReset }: UseLocalSearchStateOptions) {
  const navigate = useNavigate();
  const [selectedTags, setSelectedTags] = useState<Set<string>>(new Set());
  const searchBarRef = useRef<SearchBarRef>(null);

  // Create suggestions function for SearchBar
  const getSuggestions = useCallback(
    (input: string): TagEntry[] => getLocalSuggestions(tagSummary, input),
    [tagSummary]
  );

  // Handle "/" key to focus search bar
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      const target = e.target as HTMLElement;
      if (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA') {
        return;
      }
      if (e.key === '/') {
        e.preventDefault();
        searchBarRef.current?.focus();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  // Handle tag chip toggle
  const handleTagToggle = useCallback(
    (display: string) => {
      const newSelected = new Set(selectedTags);
      if (newSelected.has(display)) {
        newSelected.delete(display);
      } else {
        newSelected.add(display);
      }
      setSelectedTags(newSelected);

      // Update URL with selected tags
      const tags = Array.from(newSelected).join(' ');
      if (tags) {
        navigate(`${basePath}?q=${encodeURIComponent(tags)}`);
      } else {
        navigate(basePath);
      }
    },
    [selectedTags, basePath, navigate]
  );

  // Reset selected tags when needed
  const resetTags = useCallback(() => {
    setSelectedTags(new Set());
    if (onReset) {
      onReset();
    }
  }, [onReset]);

  return {
    selectedTags,
    searchBarRef,
    getSuggestions,
    handleTagToggle,
    resetTags,
  };
}
