// Edge Function: send-notification
// Sends in-app + FCM push notification to user(s)

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

interface NotifBody {
  user_id?: string         // single user
  user_ids?: string[]      // multiple users
  broadcast?: boolean      // send to all users
  user_type?: string       // 'customer' | 'winga' | 'admin'
  title: string
  body: string
  type?: string
  data?: Record<string, unknown>
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const payload: NotifBody = await req.json()
    const { title, body, type = 'info', data } = payload

    if (!title || !body) {
      return new Response(
        JSON.stringify({ success: false, error: 'title and body are required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    let userIds: string[] = []

    if (payload.user_id) {
      userIds = [payload.user_id]
    } else if (payload.user_ids) {
      userIds = payload.user_ids
    } else if (payload.broadcast || payload.user_type) {
      let query = supabaseAdmin.from('users').select('id')
      if (payload.user_type) query = query.eq('user_type', payload.user_type)
      const { data: users } = await query
      userIds = (users || []).map((u: { id: string }) => u.id)
    }

    if (userIds.length === 0) {
      return new Response(
        JSON.stringify({ success: false, error: 'No target users specified' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Insert in-app notifications
    const notifs = userIds.map(user_id => ({ user_id, title, body, type, data }))
    const { error: notifError } = await supabaseAdmin.from('notifications').insert(notifs)
    if (notifError) throw notifError

    // Get FCM tokens for push notifications
    const { data: users } = await supabaseAdmin
      .from('users')
      .select('id, fcm_token')
      .in('id', userIds)
      .not('fcm_token', 'is', null)

    let pushSent = 0
    if (users && users.length > 0 && Deno.env.get('FCM_SERVER_KEY')) {
      const fcmTokens = users
        .filter((u: { fcm_token: string | null }) => u.fcm_token)
        .map((u: { fcm_token: string }) => u.fcm_token)

      if (fcmTokens.length > 0) {
        // Send FCM push notifications
        const fcmResponse = await fetch('https://fcm.googleapis.com/fcm/send', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `key=${Deno.env.get('FCM_SERVER_KEY')}`,
          },
          body: JSON.stringify({
            registration_ids: fcmTokens,
            notification: { title, body, sound: 'default', badge: '1' },
            data: data || {},
            priority: 'high',
          }),
        })
        if (fcmResponse.ok) pushSent = fcmTokens.length
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        in_app_sent: userIds.length,
        push_sent: pushSent,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('send-notification error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
