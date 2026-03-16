// @ts-nocheck
// Supabase Edge Function: create-officer
// Deploy: supabase functions deploy create-officer --no-verify-jwt

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders, status: 200 });
  }

  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: corsHeaders }
    );
  }

  try {
    let body;
    try {
      body = await req.json();
    } catch {
      return new Response(
        JSON.stringify({ success: false, error: "Invalid JSON body" }),
        { status: 400, headers: corsHeaders }
      );
    }

    const { email, password, fullName } = body ?? {};

    console.log(`[create-officer] Request for: ${email}`);

    if (!email || !password || !fullName) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Missing required fields: email, password, fullName",
        }),
        { status: 400, headers: corsHeaders }
      );
    }

    if (password.length < 6) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Password must be at least 6 characters",
        }),
        { status: 400, headers: corsHeaders }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey) {
      console.error("[create-officer] Missing env vars");
      return new Response(
        JSON.stringify({ success: false, error: "Server configuration error" }),
        { status: 500, headers: corsHeaders }
      );
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    console.log(`[create-officer] Creating auth user: ${email}`);

    const { data: authData, error: authError } =
      await supabase.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: {
          full_name: fullName,
          role: "officer",
        },
      });

    if (authError) {
      console.error(`[create-officer] Auth error: ${authError.message}`);
      return new Response(
        JSON.stringify({ success: false, error: authError.message }),
        { status: 400, headers: corsHeaders }
      );
    }

    const userId = authData.user?.id;
    console.log(`[create-officer] Auth user created: ${userId}`);

    const { error: profileError } = await supabase.from("profile").insert({
      id: userId,
      full_name: fullName,
      role: "officer",
      is_active: true,
      must_change_password: true,
    });

    if (profileError) {
      console.warn(`[create-officer] Profile warning: ${profileError.message}`);
    }

    console.log(`[create-officer] Done: ${email}`);

    return new Response(
      JSON.stringify({
        success: true,
        message: `Officer created: ${email}`,
        user: { id: userId, email },
      }),
      { status: 200, headers: corsHeaders }
    );

  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error(`[create-officer] Unhandled error: ${msg}`);
    return new Response(
      JSON.stringify({ success: false, error: `Server error: ${msg}` }),
      { status: 500, headers: corsHeaders }
    );
  }
});