'use client';

import React, { createContext, useContext, useEffect, useState } from 'react';
import { User, Session } from '@supabase/supabase-js';
import { supabase } from '@/lib/supabase/client';
import { useRouter } from 'next/navigation';

interface AuthContextType {
  user: User | null;
  role: 'syndic' | 'resident' | 'gardien' | 'admin' | null;
  apartmentId: string | null;
  isLoading: boolean;
  signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType>({
  user: null,
  role: null,
  apartmentId: null,
  isLoading: true,
  signOut: async () => {},
});

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [role, setRole] = useState<AuthContextType['role']>(null);
  const [apartmentId, setApartmentId] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const router = useRouter();

  useEffect(() => {
    // Fetch initial session
    const getInitialSession = async () => {
      const { data: { session }, error } = await supabase.auth.getSession();

      if (error && error.message.includes('refresh_token_not_found')) {
        // Handle token expiration explicitly
        await supabase.auth.signOut();
        setUser(null);
        setRole(null);
        setApartmentId(null);
      } else if (session) {
        setUser(session.user);
        setRole(session.user.app_metadata.role || null);
        setApartmentId(session.user.app_metadata.resident_apartment_id || null);
      }
      setIsLoading(false);
    };

    getInitialSession();

    // Listen for auth changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange(async (event, session) => {
      if (event === 'TOKEN_REFRESHED' || event === 'SIGNED_IN') {
        setUser(session?.user || null);
        setRole(session?.user.app_metadata.role || null);
        setApartmentId(session?.user.app_metadata.resident_apartment_id || null);
      } else if (event === 'SIGNED_OUT') {
        setUser(null);
        setRole(null);
        setApartmentId(null);
        router.push('/login');
      }
      setIsLoading(false);
    });

    return () => {
      subscription.unsubscribe();
    };
  }, [router]);

  const signOut = async () => {
    await supabase.auth.signOut();
    router.push('/login'); // Enforce redirect after sign out
  };

  return (
    <AuthContext.Provider value={{ user, role, apartmentId, isLoading, signOut }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
