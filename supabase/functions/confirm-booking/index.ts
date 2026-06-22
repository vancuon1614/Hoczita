// Supabase Edge Function: confirm-booking
// This function verifies the customer's email, updates the database booking state to is_confirmed = true,
// sends the email to the admin (vanncuong1614@gmail.com), and returns a clean, user-friendly Vietnamese JSON response.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7"

const ADMIN_EMAIL = "vanncuong1614@gmail.com"

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
    // Parse ID from URL query parameters
    const url = new URL(req.url)
    const id = url.searchParams.get('id')

    if (!id) {
      return new Response(JSON.stringify({ "Lỗi": "Thiếu mã xác nhận lịch hẹn (Missing ID)" }), {
        status: 400,
        headers: { "Content-Type": "application/json; charset=utf-8", 'Access-Control-Allow-Origin': '*' }
      })
    }

    // Initialize Supabase Client with Service Role Key to bypass RLS policies for updating verification status
    const supabaseUrl = Deno.env.get('SUPABASE_URL') || ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // 1. Fetch the booking first to check if it exists and get information
    const { data: booking, error: fetchError } = await supabase
      .from('bookings')
      .select('*')
      .eq('id', id)
      .single()

    if (fetchError || !booking) {
      console.error("Fetch booking error:", fetchError)
      return new Response(JSON.stringify({ "Lỗi": `Không tìm thấy thông tin lịch hẹn. Lỗi: ${fetchError?.message || 'Không tìm thấy'}` }), {
        status: 404,
        headers: { "Content-Type": "application/json; charset=utf-8", 'Access-Control-Allow-Origin': '*' }
      })
    }

    const alreadyConfirmed = booking.is_confirmed

    if (!alreadyConfirmed) {
      // 2. Update the booking confirmed state
      const { error: updateError } = await supabase
        .from('bookings')
        .update({ is_confirmed: true })
        .eq('id', id)

      if (updateError) {
        console.error("Update booking error:", updateError)
        return new Response(JSON.stringify({ "Lỗi": `Lỗi khi cập nhật trạng thái lịch hẹn: ${updateError.message}` }), {
          status: 500,
          headers: { "Content-Type": "application/json; charset=utf-8", 'Access-Control-Allow-Origin': '*' }
        })
      }

      // 3. Send email to ADMIN (vanncuong1614@gmail.com)
      const { course, booking_time, full_name, phone, email, notes } = booking
      const formattedTime = new Date(booking_time).toLocaleString('vi-VN', {
        timeZone: 'Asia/Ho_Chi_Minh',
        hour: '2-digit',
        minute: '2-digit',
        day: '2-digit',
        month: '2-digit',
        year: 'numeric'
      })

      const adminSubject = `[HocZiTa Admin] Lịch hẹn tư vấn 1:1 mới ĐÃ XÁC NHẬN từ ${full_name}`
      
      const adminHtmlBody = `
        <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 12px; background-color: #ffffff;">
          <div style="background-color: #0077bb; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; color: #ffffff;">
            <h2 style="margin: 0; font-size: 22px;">Hệ thống học tập HocZiTa 🌟</h2>
            <p style="margin: 5px 0 0 0; font-size: 14px;">Lịch hẹn tư vấn 1:1 mới (Đã xác nhận)</p>
          </div>
          <div style="padding: 24px; color: #333333; line-height: 1.6;">
            <p style="font-size: 16px; font-weight: bold;">Chào Admin,</p>
            <p>Khách hàng vừa xác nhận email thành công cho yêu cầu đặt lịch hẹn tư vấn 1:1. Dưới đây là thông tin chi tiết:</p>
            
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
            
            <p>Vui lòng chủ động chuẩn bị tài liệu và liên hệ khách hàng đúng giờ hẹn.</p>
            
            <hr style="border: 0; border-top: 1px solid #eeeeee; margin: 24px 0;" />
            <p style="font-size: 13px; color: #777777; text-align: center; margin: 0;">
              Đây là email tự động từ hệ thống quản lý HocZiTa.
            </p>
          </div>
        </div>
      `

      const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')

      if (RESEND_API_KEY) {
        const response = await fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${RESEND_API_KEY}`,
          },
          body: JSON.stringify({
            from: 'HocZiTa <onboarding@resend.dev>',
            to: [ADMIN_EMAIL],
            subject: adminSubject,
            html: adminHtmlBody,
          }),
        })
        if (!response.ok) {
          throw new Error(`Resend admin notification error: ${await response.text()}`)
        }
        console.log("Admin notified via Resend API")
      } else {
        console.warn("WARNING: RESEND_API_KEY is not configured. Admin notification email is simulated.")
      }
    }

    // 4. Return a structured JSON response in Vietnamese
    const formattedTime = new Date(booking.booking_time).toLocaleString('vi-VN', {
      timeZone: 'Asia/Ho_Chi_Minh',
      hour: '2-digit',
      minute: '2-digit',
      day: '2-digit',
      month: '2-digit',
      year: 'numeric'
    })

    const successResponse = {
      "Kết quả": "Xác nhận thành công! 🎉",
      "Thông báo": "Lịch đặt tư vấn 1:1 của bạn đã được xác nhận và chuyển đến giáo viên phụ trách.",
      "Chi tiết cuộc hẹn": {
        "Họ và Tên": booking.full_name,
        "Khóa học đăng ký": booking.course,
        "Thời gian hẹn gặp": formattedTime,
        "Số điện thoại": booking.phone,
        "Email khách hàng": booking.email,
        "Trạng thái xử lý": "Đã xác nhận & Đã gửi mail cho giáo viên"
      }
    }

    return new Response(JSON.stringify(successResponse, null, 2), {
      status: 200,
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        'Access-Control-Allow-Origin': '*'
      }
    })

  } catch (error: any) {
    console.error("Error confirming booking:", error)
    return new Response(JSON.stringify({ "Lỗi hệ thống": error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json; charset=utf-8", 'Access-Control-Allow-Origin': '*' }
    })
  }
})
