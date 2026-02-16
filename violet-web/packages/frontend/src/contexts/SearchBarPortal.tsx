import { createContext, useContext } from 'react';

const SearchBarPortalContext = createContext<HTMLDivElement | null>(null);

export const SearchBarPortalProvider = SearchBarPortalContext.Provider;

export function useSearchBarPortal() {
  return useContext(SearchBarPortalContext);
}
