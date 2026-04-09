// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const inviteRedirectTo =
  Deno.env.get('INVITE_REDIRECT_TO') ||
  'https://gunathkalpitha.github.io/nbro-auth-redirect/'

function withInviteType(url: string): string {
  try {
    const parsed = new URL(url)
    if (!parsed.searchParams.has('type')) {
      parsed.searchParams.set('type', 'invite')
    }
    return parsed.toString()
  } catch {
    return url
  }
}

const supabase = createClient(supabaseUrl, supabaseServiceRoleKey)

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, x-client-info, apikey',
}

serve(async (req: Request) => {
  try {
    console.log('Received request:', req.method, req.url)
    
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
      console.log('Handling OPTIONS preflight')
      return new Response(null, {
        status: 200,
        headers: corsHeaders,
      })
    }

    // Only allow POST requests
    if (req.method !== 'POST') {
      console.log('Rejecting non-POST request:', req.method)
      return new Response(JSON.stringify({ error: 'Method not allowed' }), {
        status: 405,
        headers: { 'Content-Type': 'application/json', ...corsHeaders },
      })
    }

    console.log('Processing POST request')
    const body = await req.json()
    console.log('Request body:', body)
    const { email, fullName } = body

    if (!email || !fullName) {
      console.log('Missing email or fullName')
      return new Response(
        JSON.stringify({ error: 'Email and fullName are required' }),
        { status: 400, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      )
    }

    console.log('Inviting user:', email)
    // Invite user via email with explicit redirect page that can handle all auth URL formats.
    const { data, error } = await supabase.auth.admin.inviteUserByEmail(
      email,
      {
        redirectTo: withInviteType(inviteRedirectTo),
        data: {
          full_name: fullName,
          role: 'officer',
        }
      }
    )

    if (error) {
      console.log('Invite error:', error)
      return new Response(
        JSON.stringify({ error: error.message }),
        { status: 400, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      )
    }

    console.log('User invited, creating profile for:', data.user.id)
    // Create or update profile record
    const { error: profileError } = await supabase
      .from('profile')
      .upsert({
        id: data.user.id,
        full_name: fullName,
        role: 'officer',
        is_active: true,
      })


    if (profileError) {
      console.log('Profile creation error:', profileError)
      return new Response(
        JSON.stringify({ error: profileError.message }),
        { status: 400, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      )
    }

    console.log('Success! User created:', data.user.id)
    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Invitation email sent',
        userId: data.user.id 
      }),
      { 
        status: 200, 
        headers: { 'Content-Type': 'application/json', ...corsHeaders } 
      }
    )
  } catch (error) {
    console.log('Catch block error:', error)
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : 'Unknown error' }),
      { status: 500, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    )
  }
})
