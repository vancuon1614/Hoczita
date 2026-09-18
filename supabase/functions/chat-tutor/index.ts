import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const admin = createClient(SUPABASE_URL, SERVICE_KEY);

const SYSTEM_PROMPT = `
Bạn là "HocDi" - trợ lý học tập thông minh và là người bạn đồng hành học tập của học sinh.

### 1. QUY TẮC XƯNG HÔ (BẮT BUỘC)
- Xưng: "HocDi" hoặc "mình".
- Hô (gọi người dùng): "bạn". Hãy dùng duy nhất đại từ "bạn" xuyên suốt toàn bộ hội thoại.
- TUYỆT ĐỐI KHÔNG sử dụng các từ sau để xưng hô: "con", "bé yêu", "bé", "cháu", "nhóc", "thầy", "cô".

### 2. VĂN PHONG VÀ THÁI ĐỘ
- Lịch sự, tôn trọng, gần gũi và mang tính khích lệ như một người bạn học tốt bụng hoặc một người trợ lý thân thiện.
- Sử dụng ngôn từ trong sáng, chuẩn mực, dễ hiểu đối với lứa tuổi học sinh; tránh tiếng lóng hoặc từ ngữ quá phức tạp.
- Sử dụng emoji chừng mực (1-2 emoji mỗi câu trả lời) để tạo không khí sinh động, không lạm dụng quá nhiều.

### 3. QUY TRÌNH PHẢN HỒI KIẾN THỨC
- Trả lời thẳng vào câu hỏi một cách ngắn gọn, súc tích.
- Định dạng từ vựng/khái niệm rõ ràng (in đậm từ mới, phiên âm đơn giản, giải nghĩa tiếng Việt).
- Đưa ra 1 ví dụ cụ thể, gần gũi với đời sống học tập.
- Kết thúc bằng một lời gợi mở hoặc khích lệ nhẹ nhàng, lịch sự.

### 4. ĐIỀU CẤM KỴ
- Không tự xưng là "thầy/cô" hay người lớn bề trên.
- Không dùng từ ngữ mang tính cưng nựng quá mức ("bé cưng", "bé yêu").
- Không trách phạt hay chê bai khi người dùng trả lời sai; luôn hướng dẫn lại với thái độ kiên nhẫn.
- Không hỏi thông tin cá nhân và không bàn các chủ đề ngoài việc học tập.
`;

Deno.serve(async (req) => {
  try {
    const { userId, message, context } = await req.json();

    // 1. Kiểm tra & trừ quota (tái dùng đúng pattern flag như hint)
    let quotaAllowed = true;
    try {
      const { data: quota } = await admin.rpc('request_chat_quota', { p_user_id: userId });
      if (quota && quota.allowed === false) {
        quotaAllowed = false;
      }
    } catch (_) {
      // Nếu function chưa deploy trên DB, tạm cho phép
      quotaAllowed = true;
    }

    if (!quotaAllowed) {
      return new Response(JSON.stringify({ error: 'quota_exceeded' }), {
        status: 429,
        headers: { "Content-Type": "application/json" }
      });
    }

    // 2. Ghép context (KHÔNG chứa thông tin cá nhân)
    const contextText = context
      ? `Học sinh đang ở màn hình: ${context.screenName}. Dữ liệu liên quan: ${JSON.stringify(context.data)}`
      : '';

    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=${GEMINI_API_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [
            { role: "user", parts: [{ text: `${SYSTEM_PROMPT}\n\n${contextText}\n\nNgười dùng hỏi: ${message}\n(Lưu ý: Luôn xưng "HocDi" hoặc "mình", gọi người dùng là "bạn", tuyệt đối không dùng "con", "bé", "thầy", "cô".)` }] }
          ],
          safetySettings: [
            { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_LOW_AND_ABOVE" },
            { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_LOW_AND_ABOVE" },
            { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_LOW_AND_ABOVE" },
            { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_LOW_AND_ABOVE" },
          ],
        }),
      }
    );

    const data = await res.json();
    const reply = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "Xin lỗi, mình chưa hiểu câu hỏi. Bạn thử hỏi lại nhé! 😊";

    // 3. Lưu lịch sử (để phụ huynh/giáo viên xem lại được)
    if (userId) {
      try {
        await admin.from('chat_history').insert({
          profile_id: userId,
          user_message: message,
          ai_reply: reply,
          screen_context: context?.screenName ?? null,
        });
      } catch (err) {
        console.error("Lỗi lưu lịch sử chat:", err);
      }
    }

    return new Response(JSON.stringify({ reply }), {
      headers: { "Content-Type": "application/json" }
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: (error as Error).message }), {
      status: 500,
      headers: { "Content-Type": "application/json" }
    });
  }
});
