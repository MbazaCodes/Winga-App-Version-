// Edge Function: register-winga
// Called when a Winga submits their registration form
// Creates user record + winga record + sends notification to admin

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
}
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
const supabaseAdmin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  { auth: { autoRefreshToken: false, persistSession: false } }
)

interface RegisterWingaBody {
  phone: string
  name: string
  email?: string
  specialty: string
  home_location: string
  national_id?: string
  password: string
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const body: RegisterWingaBody = await req.json()

    const { phone, name, email, specialty, home_location, national_id, password } = body

    if (!phone || !name || !specialty || !password) {
      return new Response(
        JSON.stringify({ success: false, error: 'Missing required fields: phone, name, specialty, password' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const formattedPhone = phone.startsWith('+255') ? phone : `+255${phone.replace(/^0/, '')}`

    // Check if user already exists
    const { data: existingUser } = await supabaseAdmin
      .from('users')
      .select('id')
      .eq('phone', formattedPhone)
      .maybeSingle()

    if (existingUser) {
      return new Response(
        JSON.stringify({ success: false, error: 'Phone number already registered' }),
        { status: 409, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Create user
    const { data: user, error: userError } = await supabaseAdmin
      .from('users')
      .insert({
        phone: formattedPhone,
        email,
        name,
        user_type: 'winga',
        is_verified: false,
      })
      .select()
      .single()

    if (userError) throw userError

    // Hash password (base64 for compatibility — upgrade to bcrypt in production)
    const passwordHash = btoa(password)

    // Create credentials
    await supabaseAdmin.from('user_credentials').insert({
      user_id: user.id,
      phone: formattedPhone,
      password_hash: passwordHash,
    })

    // Create winga profile
    const { data: winga, error: wingaError } = await supabaseAdmin
      .from('wingas')
      .insert({
        user_id: user.id,
        name,
        phone: formattedPhone,
        email,
        specialty,
        home_location,
        national_id,
        verification_status: 'unverified',
        badge: 'none',
        status: 'pending',
      })
      .select()
      .single()

    if (wingaError) throw wingaError

    // Send welcome notification to winga
    await supabaseAdmin.from('notifications').insert({
      user_id: user.id,
      title: 'Karibu Winga App! 🎉',
      body: `Habari ${name}! Akaunti yako imefunguliwa. Hatua inayofuata: Lipa ada ya uthibitisho ili kuanza kupokea maombi.`,
      type: 'info',
      data: { winga_id: winga.id }
    })

    // Notify admins
    const { data: admins } = await supabaseAdmin
      .from('users')
      .select('id')
      .eq('user_type', 'admin')

    if (admins && admins.length > 0) {
      const adminNotifs = admins.map((admin: { id: string }) => ({
        user_id: admin.id,
        title: `Winga Mpya — ${name}`,
        body: `${name} (${specialty}) amejiandikisha. Anasubiri kuanza mchakato wa uthibitisho.`,
        type: 'info',
        data: { winga_id: winga.id, user_id: user.id }
      }))
      await supabaseAdmin.from('notifications').insert(adminNotifs)
    }

    return new Response(
      JSON.stringify({
        success: true,
        user_id: user.id,
        winga_id: winga.id,
        winga_code: winga.winga_id,
        message: 'Registration successful. Please pay verification fee to get started.',
      }),
      { status: 201, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('register-winga error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
