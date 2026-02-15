import { useState, useEffect, useRef, useCallback } from 'react';
import { useNavigate } from 'react-router';
import { useQuery } from '@tanstack/react-query';
import type { BookmarkCropImage } from '@violet-web/shared';
import { resolveGallery, getProxyImageUrl } from '../../api/proxy';
import { useArticle } from '../../hooks/useArticle';
import { ArticleInfoDialog } from '../search/ArticleInfoDialog';
import styles from './CropImageCard.module.css';

interface CropImageCardProps {
  crop: BookmarkCropImage;
  onDelete: (id: number) => void;
}

function parseCropArea(area: string) {
  const [left, top, right, bottom] = area.split(',').map(Number);
  return { left, top, right, bottom };
}

export function CropImageCard({ crop, onDelete }: CropImageCardProps) {
  const navigate = useNavigate();
  const cardRef = useRef<HTMLDivElement>(null);
  const [visible, setVisible] = useState(false);
  const [showInfoDialog, setShowInfoDialog] = useState(false);
  const { data: article } = useArticle(showInfoDialog ? crop.Article : 0);

  // IntersectionObserver for lazy loading
  useEffect(() => {
    const el = cardRef.current;
    if (!el) return;
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setVisible(true);
          observer.disconnect();
        }
      },
      { rootMargin: '200px' },
    );
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  const { left, top, right, bottom } = parseCropArea(crop.Area);
  const cropWidth = right - left;
  const cropHeight = bottom - top;
  const cropAspectRatio = (cropWidth * crop.AspectRatio) / cropHeight;

  const { data: gallery } = useQuery({
    queryKey: ['gallery', crop.Article],
    queryFn: () => resolveGallery(crop.Article),
    enabled: visible,
    staleTime: 5 * 60 * 1000,
  });

  const imageUrl = gallery
    ? getProxyImageUrl(
        gallery.urls[crop.Page],
        `https://hitomi.la/reader/${crop.Article}.html`,
      )
    : null;

  const handleClick = useCallback(() => {
    navigate(`/viewer/${crop.Article}?p=${crop.Page}`);
  }, [navigate, crop.Article, crop.Page]);

  const handleDelete = useCallback(
    (e: React.MouseEvent) => {
      e.stopPropagation();
      onDelete(crop.Id);
    },
    [onDelete, crop.Id],
  );

  return (
    <>
      <div ref={cardRef} className={styles.card} onClick={handleClick}>
        <div
          className={styles.imageWrapper}
          style={{ aspectRatio: String(cropAspectRatio) }}
        >
          {imageUrl ? (
            <img
              className={styles.image}
              src={imageUrl}
              loading="lazy"
              style={{
                width: `${(1 / cropWidth) * 100}%`,
                left: `${(-left / cropWidth) * 100}%`,
                top: `${(-top / cropHeight) * 100}%`,
              }}
            />
          ) : (
            visible && <div className={styles.placeholder}>Loading...</div>
          )}
        </div>
        <button className={styles.deleteBtn} onClick={handleDelete} title="Delete">
          ×
        </button>
        <div className={styles.overlay}>
          <span
            className={styles.articleLink}
            onClick={(e) => { e.stopPropagation(); setShowInfoDialog(true); }}
          >
            #{crop.Article}
          </span>
          {' · p'}{crop.Page + 1}
        </div>
      </div>
      {showInfoDialog && article && (
        <ArticleInfoDialog article={article} onClose={() => setShowInfoDialog(false)} />
      )}
    </>
  );
}
