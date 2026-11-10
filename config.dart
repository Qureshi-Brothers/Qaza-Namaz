// Yahan apne Supabase project ki details likhein.
// Supabase > Project Settings > API se "Project URL" aur "anon public" key copy karein.
// (anon key secret nahi hoti, app mein rakhna theek hai.)
// Agar yahan kuch na likhein to app bina account ke (sirf phone mein) chalegi.

const String supabaseUrl = 'https://ntjtlmjxrrqgrwdxkjxo.supabase.co';
const String supabaseAnonKey = 'sb_publishable_R7vvL2-kvJ5EOIBDT0mUMA_SlNIdysJ;

bool get supabaseConfigured =>
    supabaseUrl.startsWith('https://') && supabaseAnonKey.length > 20;
