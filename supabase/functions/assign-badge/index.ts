// Edge Function: assign-badge
// Admin assigns/changes badge for a verified winga
// POST { winga_id, badge: 'Starter' | 'Mid' | 'Verified' }

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

const BADGE_CONFIG = {
  Starter:  { emoji: '🥉', color: '#CD7F32', label: 'Starter Winga' },
  Mid:      { emoji: '🥈', color: '#C0C0C0', label: 'Mid Winga' },
  Verified: { emoji: '🥇', color: '#F9A825', label: 'Verified Winga' },
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { winga_id, badge, reason } = await req.json()

    if (!winga_id || !badge) {
      return new Response(
        JSON.stringify({ success: false, error: 'Missing winga_id or badge' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!['Starter', 'Mid', 'Verified'].includes(badge)) {
      return new Response(
        JSON.stringify({ success: false, error: 'badge must be: Starter, Mid, or Verified' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { data: winga, error } = await supabaseAdmin
      .from('wingas')
      .select('id, user_id, name, badge, verification_status')
      .eq('id', winga_id)
      .single()

    if (error || !winga) {
      return new Response(
        JSON.stringify({ success: false, error: 'Winga not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (winga.verification_status !== 'verified') {
      return new Response(
        JSON.stringify({ success: false, error: 'Winga must be verified before assigning a badge' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const previousBadge = winga.badge
    const config = BADGE_CONFIG[badge as keyof typeof BADGE_CONFIG]

    // Update badge
    await supabaseAdmin.from('wingas').update({
      badge,
      badge_assigned_at: new Date().toISOString(),
      badge_expires_at: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
      verification_tier: badge,
    }).eq('id', winga_id)

    // Notify winga
    const isUpgrade = ['none', 'Starter', 'Mid'].indexOf(previousBadge) <
                      ['Starter', 'Mid', 'Verified'].indexOf(badge)

    await supabaseAdmin.from('notifications').insert({
      user_id: winga.user_id,
      title: `${config.emoji} Badge Yako: ${config.label}`,
      body: isUpgrade
        ? `Hongera ${winga.name}! Badge yako imeboreshwa hadi ${badge}. ${reason || ''}`
        : `Badge yako imebadilishwa hadi ${badge}. ${reason || ''}`,
      type: 'success',
      data: { badge, previous_badge: previousBadge, winga_id }
    })

    return new Response(
      JSON.stringify({
        success: true,
        winga_id,
        badge,
        previous_badge: previousBadge,
        badge_color: config.color,
        badge_label: config.label,
        expires_in_days: 30,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('assign-badge error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
