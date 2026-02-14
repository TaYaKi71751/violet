import { Outlet } from 'react-router';
import { TopBar } from './TopBar';
import { Sidebar } from './Sidebar';
import { BottomNav } from './BottomNav';
import { useIsMobile, useIsDesktop } from '../../hooks/useMediaQuery';
import styles from './AppShell.module.css';

export function AppShell() {
  const isMobile = useIsMobile();
  const isDesktop = useIsDesktop();

  return (
    <div className={styles.shell}>
      <TopBar />
      <div className={styles.body}>
        {isDesktop && <Sidebar />}
        <main className={styles.content}>
          <Outlet />
        </main>
      </div>
      {isMobile && <BottomNav />}
    </div>
  );
}
