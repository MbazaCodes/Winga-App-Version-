// Edge Function: initiate-payment
// Initiates verification fee payment via mobile money
// In production: integrate with Selcom / Azampesa / Mpesa Tanzania API

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

interface PaymentBody {
  winga_id: string
  tier_name: 'Starter' | 'Mid' | 'Verified'
  payment_method: 'mpesa' | 'airtel' | 'tigo' | 'halopesa' | 'card'
  mobile_number?: string
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const body: PaymentBody = await req.json()
    const { winga_id, tier_name, payment_method, mobile_number } = body

    if (!winga_id || !tier_name || !payment_method) {
      return new Response(
        JSON.stringify({ success: false, error: 'Missing required fields' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get tier details
    const { data: tier, error: tierError } = await supabaseAdmin
      .from('verification_tiers')
      .select('*')
      .eq('name', tier_name)
      .single()

    if (tierError || !tier) {
      return new Response(
        JSON.stringify({ success: false, error: 'Invalid tier' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get winga
    const { data: winga, error: wingaError } = await supabaseAdmin
      .from('wingas')
      .select('*, users(name, phone)')
      .eq('id', winga_id)
      .single()

    if (wingaError || !winga) {
      return new Response(
        JSON.stringify({ success: false, error: 'Winga not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ── In production: call mobile money API here ──────────────────────
    // Example for Selcom Tanzania:
    // const selcomResponse = await fetch('https://apigw.selcommobile.com/v1/checkout/create-order', {
    //   method: 'POST',
    //   headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${Deno.env.get('SELCOM_API_KEY')}` },
    //   body: JSON.stringify({
    //     vendor: Deno.env.get('SELCOM_VENDOR'),
    //     order_id: `WNGA-${Date.now()}`,
    //     amount: tier.monthly_fee,
    //     currency: 'TZS',
    //     msisdn: mobile_number,
    //     name: winga.name,
    //     email: winga.email,
    //     webhook: `${Deno.env.get('SUPABASE_URL')}/functions/v1/confirm-payment`,
    //   })
    // })
    // ──────────────────────────────────────────────────────────────────

    // For now: simulate successful payment initiation
    const provider_ref = `WNG-${Date.now()}-${Math.random().toString(36).substr(2, 6).toUpperCase()}`

    // Create pending payment record
    const { data: payment, error: paymentError } = await supabaseAdmin
      .from('verification_payments')
      .insert({
        winga_id,
        tier_id: tier.id,
        amount: tier.monthly_fee,
        payment_method,
        mobile_number,
        provider_ref,
        status: 'pending',
        month_covered: new Date().toISOString().substr(0, 7) + '-01',
      })
      .select()
      .single()

    if (paymentError) throw paymentError

    // Update winga status
    await supabaseAdmin
      .from('wingas')
      .update({ verification_status: 'payment_pending', verification_tier: tier_name })
      .eq('id', winga_id)

    return new Response(
      JSON.stringify({
        success: true,
        payment_id: payment.id,
        provider_ref,
        amount: tier.monthly_fee,
        tier: tier_name,
        message: payment_method === 'mpesa' || payment_method === 'airtel' || payment_method === 'tigo' || payment_method === 'halopesa'
          ? `Ombi la malipo limetumwa kwa ${mobile_number}. Thibitisha kwa kuingiza PIN yako.`
          : 'Payment initiated. Please complete payment.',
        // In production, return checkout_url for card or push notification reference for mobile money
        checkout_url: null,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('initiate-payment error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
