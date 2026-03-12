// config.dart
// DO NOT COMMIT THIS FILE - it is listed in .gitignore
//
// How to set up:
//   1. Copy lib/config.dart.example to lib/config.dart
//   2. Fill in your Supabase URL and anon key (from Supabase Dashboard -> Project Settings -> API)
//
// Note: The Supabase anon key is a PUBLIC key by design (Supabase security model).
//       Security is enforced by Row Level Security (RLS) policies on your database,
//       NOT by keeping the anon key secret.

const supabaseUrl = 'https://bazelkzuwxcrmapbuzyp.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJhemVsa3p1d3hjcm1hcGJ1enlwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg4MjY0NTYsImV4cCI6MjA4NDQwMjQ1Nn0.bCuiTsDIXKKQaqPRVBcTfrp44APXtCAp8QpovVaBywk';
