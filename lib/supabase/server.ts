import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'
import type { Database } from '@/types/database'

/**
 * Supabase server client untuk digunakan di Server Actions dan React Server Components (RSC).
 * Menggunakan Next.js `cookies()` API (async di Next.js 15+) untuk cookie handling.
 * Requirements: 5.9, 9.6
 */
export async function createClient() {
  const cookieStore = await cookies()

  return createServerClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll()
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) => {
              cookieStore.set(name, value, options)
            })
          } catch {
            // `setAll` dipanggil dari Server Component — cookie tidak bisa di-set
            // saat rendering RSC. Ini aman diabaikan karena middleware akan
            // me-refresh session sebelum halaman di-load.
          }
        },
      },
    }
  )
}
