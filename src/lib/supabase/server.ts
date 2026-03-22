import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';
import { env } from '../env';
import type { Database } from './types';

export async function createClient() {
  const cookieStore = await cookies();

  return createServerClient<Database>(
    env.NEXT_PUBLIC_SUPABASE_URL!,
    env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options)
            );
          } catch {
            // Ignored if called from a Server Component.
          }
        },
      },
    }
  );
}

// For use in API routes ONLY
export async function createAdminClient() {
  const cookieStore = await cookies();
  const adminKey = env['SUPABASE_SERVICE_ROLE_KEY' as keyof typeof env];

  return createServerClient<Database>(
    env.NEXT_PUBLIC_SUPABASE_URL!,
    adminKey!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options)
            );
          } catch {
            // Ignore for Server Components
          }
        },
      },
    }
  );
}
