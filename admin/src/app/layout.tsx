import './globals.css';
import type { Metadata } from 'next';
import { AdminShell } from '../components/layout/admin-shell';

export const metadata: Metadata = {
  title: 'Winga Admin V3',
  description: 'Winga Admin V3 dashboard',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <AdminShell>{children}</AdminShell>
      </body>
    </html>
  );
}
