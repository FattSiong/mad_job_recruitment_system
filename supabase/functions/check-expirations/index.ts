import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// 👉 PASTE YOUR ACTUAL KEYS HERE
const ONESIGNAL_APP_ID = "595705d0-3319-4ced-90ab-22185bb761dc";
const ONESIGNAL_REST_API_KEY = "os_v2_app_lflqlubtdfgo3efleimfxn3b3r2pcgb4dmvu53ff2dejac4fschvkyxktqwln34ueqxmweuerp3zo6tgz5tyho62fckklslqf3ecm7q";

serve(async (req) => {
  try {
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 1. Define the 24-hour window for exactly 3 days from now
    const startOfTarget = new Date();
    startOfTarget.setDate(startOfTarget.getDate() + 3);
    startOfTarget.setUTCHours(0, 0, 0, 0);

    const endOfTarget = new Date(startOfTarget);
    endOfTarget.setUTCHours(23, 59, 59, 999);

    // 2. Query using a range (GTE = Greater Than or Equal, LTE = Less Than or Equal)
    const { data: expiringSubs, error } = await supabaseAdmin
      .from('PaymentSubscription')
      .select(`
        companyID,
        endDate,
        Company!inner ( notification_token )
      `)
      .eq('status', 'active')
      .gte('endDate', startOfTarget.toISOString())
      .lte('endDate', endOfTarget.toISOString());

    if (error) throw error;

    if (!expiringSubs || expiringSubs.length === 0) {
      return new Response(JSON.stringify({
        message: `No expiries found between ${startOfTarget.toISOString()} and ${endOfTarget.toISOString()}`
      }), { status: 200 });
    }

    // 3. Collect tokens
    const tokens: string[] = [];
    expiringSubs.forEach((sub: any) => {
      const token = sub.Company?.notification_token;
      if (token) tokens.push(token);
    });

    if (tokens.length === 0) {
      return new Response(JSON.stringify({ message: "Matches found, but no notification tokens saved." }), { status: 200 });
    }

    // 4. Send OneSignal Request
    const oneSignalRes = await fetch("https://onesignal.com/api/v1/notifications", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Basic ${ONESIGNAL_REST_API_KEY}`
      },
      body: JSON.stringify({
        app_id: ONESIGNAL_APP_ID,
        include_player_ids: tokens,
        headings: { "en": "Subscription Expiring! ⚠️" },
        contents: { "en": "Your Premium Plan expires in 3 days. Renew now to keep AI features active!" }
      })
    });

    const result = await oneSignalRes.json();
    return new Response(JSON.stringify({ message: "Done!", result }), { status: 200 });

  } catch (err: any) {
    // This will now show more detail if something else goes wrong
    return new Response(JSON.stringify({ error: err.message }), { status: 500 })
  }
})