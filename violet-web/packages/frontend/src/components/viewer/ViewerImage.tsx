import { useState, useRef, useEffect } from 'react';
import styles from './ViewerImage.module.css';

interface ViewerImageProps {
  src: string;
  alt?: string;
  onLoad?: () => void;
}

export function ViewerImage({ src, alt = '', onLoad }: ViewerImageProps) {
  const [loaded, setLoaded] = useState(false);
  const [error, setError] = useState(false);
  const [retryCount, setRetryCount] = useState(0);
  const imgRef = useRef<HTMLImageElement>(null);

  useEffect(() => {
    setLoaded(false);
    setError(false);
  }, [src]);

  const retry = () => {
    setError(false);
    setRetryCount((c) => c + 1);
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
          onError={() => setError(true)}
        />
      ) : (
        <div className={styles.error} onClick={retry}>
          Failed to load image. Click to retry.
        </div>
      )}
      {!loaded && !error && (
        <div className={styles.loading}>Loading...</div>
      )}
    </div>
  );
}
