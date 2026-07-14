import './globals.css';
import type { Metadata, Viewport } from 'next';
import ClientLayout from './client-layout';

export const metadata: Metadata = {
  title: 'Winga PWA',
  description: 'Mobile-like PWA for customers and Winga agents to book rides, track status, and manage payments.',
  manifest: '/manifest.webmanifest',
  icons: [{ rel: 'icon', url: '/icons/icon-192.png' }],
};

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  maximumScale: 1,
  viewportFit: 'cover',
  themeColor: '#1A5C2A',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <ClientLayout>{children}</ClientLayout>
      </body>
    </html>
  );
}
