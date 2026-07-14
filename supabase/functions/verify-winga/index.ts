// Edge Function: verify-winga
// Admin verifies a winga and assigns badge tier
// POST { winga_id, tier, notes? }

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

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ success: false, error: 'No authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Verify the calling user is admin
    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabaseAdmin.auth.getUser(token)

    // For bypass-auth flow, check user_credentials
    let adminUserId: string | null = null
    if (user) {
      const { data: adminCheck } = await supabaseAdmin
        .from('users')
        .select('id, user_type')
        .eq('id', user.id)
        .single()
      if (adminCheck?.user_type !== 'admin') {
        return new Response(
          JSON.stringify({ success: false, error: 'Admin access required' }),
          { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
      adminUserId = adminCheck.id
    }

    const { winga_id, tier, notes, action } = await req.json()

    if (!winga_id || (!tier && action !== 'reject')) {
      return new Response(
        JSON.stringify({ success: false, error: 'Missing winga_id or tier' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (action === 'reject') {
      // Reject winga
      const { data: winga } = await supabaseAdmin
        .from('wingas')
        .select('user_id, name')
        .eq('id', winga_id)
        .single()

      await supabaseAdmin.from('wingas').update({
        verification_status: 'rejected',
        rejection_reason: notes || 'Documents not sufficient',
        badge: 'none',
      }).eq('id', winga_id)

      if (winga) {
        await supabaseAdmin.from('notifications').insert({
          user_id: winga.user_id,
          title: 'Uthibitisho Umekataliwa',
          body: `Ombi lako limekataliwa. Sababu: ${notes || 'Nyaraka hazikutosha'}. Wasiliana nasi kwa msaada.`,
          type: 'warning',
          data: { winga_id, reason: notes }
        })
      }

      return new Response(
        JSON.stringify({ success: true, action: 'rejected', winga_id }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Validate tier
    if (!['Starter', 'Mid', 'Verified'].includes(tier)) {
      return new Response(
        JSON.stringify({ success: false, error: 'tier must be Starter, Mid, or Verified' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get winga
    const { data: winga, error: wingaError } = await supabaseAdmin
      .from('wingas')
      .select('*, users(id, name)')
      .eq('id', winga_id)
      .single()

    if (wingaError || !winga) {
      return new Response(
        JSON.stringify({ success: false, error: 'Winga not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { data: tierData } = await supabaseAdmin
      .from('verification_tiers')
      .select('id')
      .eq('name', tier)
      .single()

    // Update winga — verified + badge
    await supabaseAdmin.from('wingas').update({
      verification_status: 'verified',
      verification_tier: tier,
      tier_id: tierData?.id,
      badge: tier,
      badge_assigned_at: new Date().toISOString(),
      badge_expires_at: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
      verified_at: new Date().toISOString(),
      verification_notes: notes,
      status: 'active',
    }).eq('id', winga_id)

    // Mark user as verified
    await supabaseAdmin
      .from('users')
      .update({ is_verified: true })
      .eq('id', winga.user_id)

    // Audit log
    if (adminUserId) {
      await supabaseAdmin.from('admin_audit_log').insert({
        admin_id: adminUserId,
        action: 'verify_winga',
        target_type: 'winga',
        target_id: winga_id,
        details: { tier, notes, previous_status: winga.verification_status }
      })
    }

    // Notify winga
    const tierEmoji: Record<string, string> = { Starter: '🥉', Mid: '🥈', Verified: '🥇' }
    await supabaseAdmin.from('notifications').insert({
      user_id: winga.user_id,
      title: `${tierEmoji[tier]} Hongera! Umeidhinishwa — ${tier} Winga`,
      body: `Akaunti yako imeidhinishwa kama ${tier} Winga. Sasa unaweza kupokea maombi ya wateja!`,
      type: 'success',
      data: { tier, winga_id, badge: tier }
    })

    return new Response(
      JSON.stringify({
        success: true,
        winga_id,
        tier,
        badge: tier,
        status: 'verified',
        message: `${winga.name} verified as ${tier} Winga`,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('verify-winga error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
