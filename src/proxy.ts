import { NextResponse, type NextRequest } from 'next/server';
import { createServerClient } from '@supabase/ssr';

export async function proxy(request: NextRequest) {
  let supabaseResponse = NextResponse.next({
    request,
  });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value, options }) => request.cookies.set(name, value));
          supabaseResponse = NextResponse.next({
            request,
          });
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options)
          );
        },
      },
    }
  );

  // refreshing the auth token
  const {
    data: { user },
    error,
  } = await supabase.auth.getUser();

  const isAuthRoute = request.nextUrl.pathname.startsWith('/login') || request.nextUrl.pathname.startsWith('/admin/login');

  if (!user && !isAuthRoute) {
    // Return a 307 redirect
    const url = request.nextUrl.clone();
    url.pathname = '/login';
    return NextResponse.redirect(url, { status: 307 });
  }

  if (user && isAuthRoute) {
    // User is logged in, restrict access to auth routes
    const role = user.app_metadata.role;
    const url = request.nextUrl.clone();

    if (role === 'syndic' || role === 'admin' || role === 'gestionnaire') {
      url.pathname = '/syndic/dashboard';
    } else {
      url.pathname = '/resident/dashboard';
    }
    return NextResponse.redirect(url, { status: 307 });
  }

  // Route-based authorization for protected routes
  if (user && !isAuthRoute) {
    const role = user.app_metadata.role;
    const isSyndicRoute = request.nextUrl.pathname.startsWith('/syndic');
    const isResidentRoute = request.nextUrl.pathname.startsWith('/resident');
    const isSyndicOrAdmin = role === 'syndic' || role === 'admin' || role === 'gestionnaire';

    if (isSyndicRoute && !isSyndicOrAdmin) {
      // Resident trying to access syndic dashboard
      const url = request.nextUrl.clone();
      url.pathname = '/resident/dashboard';
      return NextResponse.redirect(url, { status: 307 });
    }

    if (isResidentRoute && role !== 'resident') {
      // Syndic trying to access resident dashboard directly
      const url = request.nextUrl.clone();
      url.pathname = '/syndic/dashboard';
      return NextResponse.redirect(url, { status: 307 });
    }
  }

  return supabaseResponse;
}

export const config = {
  matcher: [
    /*
     * Match all request paths except for the ones starting with:
     * - _next/static (static files)
     * - _next/image (image optimization files)
     * - favicon.ico (favicon file)
     * - public files
     * Feel free to modify this pattern to include more paths.
     */
    '/((?!_next/static|_next/image|favicon.ico|manifest.json|icons|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
};
