import type { Metadata } from 'next';
import './globals.css';
import { AuthProvider } from '@/contexts/AuthContext';

export const metadata: Metadata = {
  title: 'Syndic Management PWA - L\'Amandier B',
  description: 'Syndic management application',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="fr">
      <body>
        <AuthProvider>
          {children}
        </AuthProvider>
      </body>
    </html>
  );
}
