import { createClient, type SupabaseClient, type User } from 'npm:@supabase/supabase-js@2';

/** Клиент с ключом service_role: обходит RLS. Только внутри функций, наружу не отдаётся. */
export function adminClient(): SupabaseClient {
  return createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: { persistSession: false },
  });
}

/** Пользователь по заголовку Authorization (JWT из приложения или админки). */
export async function currentUser(req: Request): Promise<User | null> {
  const token = req.headers.get('Authorization')?.replace(/^Bearer\s+/i, '');
  if (!token) return null;
  const { data, error } = await adminClient().auth.getUser(token);
  return error ? null : data.user;
}

export async function isAdmin(db: SupabaseClient, userId: string): Promise<boolean> {
  const { data } = await db.from('admins').select('user_id').eq('user_id', userId).maybeSingle();
  return data !== null;
}
