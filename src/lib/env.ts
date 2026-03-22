export const env = {
  NEXT_PUBLIC_SUPABASE_URL: process.env.NEXT_PUBLIC_SUPABASE_URL,
  NEXT_PUBLIC_SUPABASE_ANON_KEY: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
  SUPABASE_SERVICE_ROLE_KEY: process.env.SUPABASE_SERVICE_ROLE_KEY,
  SIGNING_PRIVATE_KEY_PEM: process.env.SIGNING_PRIVATE_KEY_PEM,
};

const requiredEnvs = [
  'NEXT_PUBLIC_SUPABASE_URL',
  'NEXT_PUBLIC_SUPABASE_ANON_KEY',
  'SUPABASE_SERVICE_ROLE_KEY',
  'SIGNING_PRIVATE_KEY_PEM',
];

for (const key of requiredEnvs) {
  if (!process.env[key]) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
}
