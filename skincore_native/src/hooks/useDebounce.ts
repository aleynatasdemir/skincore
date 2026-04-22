import { useEffect, useState } from 'react';

/**
 * Debounce hook — Swift Combine .debounce karşılığı
 * @param value izlenecek değer
 * @param delay ms cinsinden gecikme (varsayılan 350ms)
 */
export function useDebounce<T>(value: T, delay = 350): T {
  const [debouncedValue, setDebouncedValue] = useState<T>(value);

  useEffect(() => {
    const timer = setTimeout(() => {
      setDebouncedValue(value);
    }, delay);

    return () => {
      clearTimeout(timer);
    };
  }, [value, delay]);

  return debouncedValue;
}
