// Supabase Edge Function: send-booking-email
// This function sends the confirmation verification email to the customer when a new booking is created.
// It uses the Resend API (via standard fetch) to ensure 100% compatibility with Deno Deploy.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  // CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      }
    })
  }

  try {
    const { record } = await req.json()
    if (!record) {
      return new Response(JSON.stringify({ error: "Missing record data" }), {
        status: 400,
        headers: { "Content-Type": "application/json" }
      })
    }

    const { id, course, booking_time, full_name, phone, email, notes } = record
    const formattedTime = new Date(booking_time).toLocaleString('vi-VN', {
      timeZone: 'Asia/Ho_Chi_Minh',
      hour: '2-digit',
      minute: '2-digit',
      day: '2-digit',
      month: '2-digit',
      year: 'numeric'
    })

    // Auto get supabase url to construct confirmation link
    const supabaseUrl = Deno.env.get('SUPABASE_URL') || 'https://sinqzsswmecneliyjfrg.supabase.co'
    const confirmLink = `${supabaseUrl}/functions/v1/confirm-booking?id=${id}`

    const emailSubject = `[HocZiTa] Xác nhận địa chỉ email đặt lịch tư vấn 1:1 - Khóa học ${course}`

    // Beautiful HTML content for the customer with verification button
    const htmlBody = `
      <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 12px; background-color: #ffffff;">
        <div style="background-color: #0077bb; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; color: #ffffff;">
          <h2 style="margin: 0; font-size: 22px;">Hệ thống học tập HocZiTa 🌟</h2>
          <p style="margin: 5px 0 0 0; font-size: 14px;">Xác nhận đặt lịch tư vấn 1:1</p>
        </div>
        <div style="padding: 24px; color: #333333; line-height: 1.6;">
          <p style="font-size: 16px; font-weight: bold;">Chào bạn ${full_name},</p>
          <p>Cảm ơn bạn đã đăng ký lịch tư vấn 1:1 tại HocZiTa. Để hoàn tất đặt lịch và gửi thông tin cho giáo viên, <b>vui lòng nhấn vào nút xác nhận dưới đây</b>:</p>
          
          <div style="text-align: center; margin: 30px 0;">
            <a href="${confirmLink}" style="background-color: #00ca71; color: white; padding: 14px 28px; text-decoration: none; font-weight: bold; border-radius: 8px; font-size: 16px; display: inline-block; box-shadow: 0 4px 6px rgba(0,202,113,0.2);">
              XÁC NHẬN LỊCH HẸN 📅
            </a>
          </div>

          <p style="color: #666666; font-size: 14px; text-align: center;">
            Nếu nút trên không hoạt động, bạn có thể sao chép và dán liên kết sau vào trình duyệt:<br/>
            <a href="${confirmLink}" style="color: #0077bb; word-break: break-all;">${confirmLink}</a>
          </p>
          
          <div style="background-color: #f5fafd; border-left: 4px solid #0077bb; padding: 16px; margin: 20px 0; border-radius: 0 8px 8px 0;">
            <table style="width: 100%; border-collapse: collapse;">
              <tr>
                <td style="padding: 6px 0; font-weight: bold; width: 35%; color: #555555;">Khóa học:</td>
                <td style="padding: 6px 0; color: #333333;">${course}</td>
              </tr>
              <tr>
                <td style="padding: 6px 0; font-weight: bold; color: #555555;">Thời gian hẹn:</td>
                <td style="padding: 6px 0; color: #333333; font-weight: bold;">${formattedTime}</td>
              </tr>
              <tr>
                <td style="padding: 6px 0; font-weight: bold; color: #555555;">Họ và Tên:</td>
                <td style="padding: 6px 0; color: #333333;">${full_name}</td>
              </tr>
              <tr>
                <td style="padding: 6px 0; font-weight: bold; color: #555555;">Số điện thoại:</td>
                <td style="padding: 6px 0; color: #333333;">${phone}</td>
              </tr>
              <tr>
                <td style="padding: 6px 0; font-weight: bold; color: #555555;">Email liên hệ:</td>
                <td style="padding: 6px 0; color: #333333;">${email}</td>
              </tr>
              <tr>
                <td style="padding: 6px 0; font-weight: bold; color: #555555; vertical-align: top;">Ghi chú:</td>
                <td style="padding: 6px 0; color: #333333;">${notes || '<i>Không có ghi chú thêm</i>'}</td>
              </tr>
            </table>
          </div>
          
          <p><i>Lưu ý: Yêu cầu đặt lịch của bạn chỉ được chuyển đến giáo viên phụ trách sau khi bạn xác nhận qua email này.</i></p>
          
          <hr style="border: 0; border-top: 1px solid #eeeeee; margin: 24px 0;" />
          <p style="font-size: 13px; color: #777777; text-align: center; margin: 0;">
            Đây là email tự động từ hệ thống quản lý HocZiTa. Vui lòng không trả lời trực tiếp email này.
          </p>
        </div>
      </div>
    `

    const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')

    if (RESEND_API_KEY) {
      // Send via Resend API
      const response = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${RESEND_API_KEY}`,
        },
        body: JSON.stringify({
          from: 'HocZiTa <onboarding@resend.dev>',
          to: [email],
          subject: emailSubject,
          html: htmlBody,
        }),
      })
      if (!response.ok) {
        throw new Error(`Resend error: ${await response.text()}`)
      }
      console.log("Verification email sent to customer via Resend API")
    } else {
      console.warn("WARNING: RESEND_API_KEY is not configured. Email is simulated.")
    }

    return new Response(JSON.stringify({ success: true, message: "Verification email sent to customer" }), {
      status: 200,
      headers: { "Content-Type": "application/json", 'Access-Control-Allow-Origin': '*' }
    })

  } catch (error: any) {
    console.error("Error sending verification email in Edge Function:", error)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json", 'Access-Control-Allow-Origin': '*' }
    })
  }
})
