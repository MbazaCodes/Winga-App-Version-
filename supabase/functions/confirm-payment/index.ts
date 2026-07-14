// Edge Function: confirm-payment
// Called by payment provider webhook OR manually by admin
// Confirms payment and moves winga to under_review

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
    const body = await req.json()
    const { payment_id, provider_ref, winga_id, tier_name, payment_method, mobile_number } = body

    if (!winga_id || !tier_name) {
      return new Response(
        JSON.stringify({ success: false, error: 'Missing winga_id or tier_name' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Call the DB RPC to confirm payment + move to under_review
    const { data, error } = await supabaseAdmin.rpc('confirm_verification_payment', {
      p_winga_id: winga_id,
      p_tier_name: tier_name,
      p_payment_method: payment_method || 'mpesa',
      p_mobile_number: mobile_number || null,
      p_provider_ref: provider_ref || null,
    })

    if (error) throw error

    // Mark payment record as success if we have payment_id
    if (payment_id) {
      await supabaseAdmin
        .from('verification_payments')
        .update({ status: 'success', paid_at: new Date().toISOString() })
        .eq('id', payment_id)
    }

    return new Response(
      JSON.stringify({ success: true, ...data }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('confirm-payment error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
