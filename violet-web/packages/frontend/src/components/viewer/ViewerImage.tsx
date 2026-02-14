import { useState, useRef, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import styles from './ViewerImage.module.css';

interface ViewerImageProps {
  src: string;
  alt?: string;
  active?: boolean; // If false, show placeholder instead of loading image
  onLoad?: () => void;
}

const MAX_RETRIES = 10;
const RETRY_DELAY = 1500; // 1.5 seconds

export function ViewerImage({ src, alt = '', active = true, onLoad }: ViewerImageProps) {
  const { t } = useTranslation();
  const [loaded, setLoaded] = useState(false);
  const [error, setError] = useState(false);
  const [retryCount, setRetryCount] = useState(0);
  const imgRef = useRef<HTMLImageElement>(null);
  const retryTimeoutRef = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);

  useEffect(() => {
    setLoaded(false);
    setError(false);
    setRetryCount(0);
  }, [src]);

  // If not active, don't load the image
  if (!active) {
    return <div className={styles.container} />;
  }

  useEffect(() => {
    return () => {
      if (retryTimeoutRef.current) {
        clearTimeout(retryTimeoutRef.current);
      }
    };
  }, []);

  const handleError = () => {
    if (retryCount < MAX_RETRIES) {
      // Auto retry after delay
      retryTimeoutRef.current = setTimeout(() => {
        setRetryCount((c) => c + 1);
      }, RETRY_DELAY);
    } else {
      // Max retries exceeded
      setError(true);
    }
  };

  const manualRetry = () => {
    setError(false);
    setRetryCount(0);
  };

  const handleLoad = () => {
    setLoaded(true);
    onLoad?.();
  };

  return (
    <div className={styles.container}>
      {!error ? (
        <img
          ref={imgRef}
          key={`${src}-${retryCount}`}
          src={src}
          alt={alt}
          className={`${styles.image} ${loaded ? styles.loaded : ''}`}
          onLoad={handleLoad}
          onError={handleError}
        />
      ) : (
        <div className={styles.error} onClick={manualRetry}>
          {t('viewer.loadError', { max: MAX_RETRIES })}
        </div>
      )}
      {!loaded && !error && (
        <div className={styles.loading}>
          {retryCount > 0
            ? t('viewer.retrying', { current: retryCount, max: MAX_RETRIES })
            : t('viewer.loading')}
        </div>
      )}
    </div>
  );
}
