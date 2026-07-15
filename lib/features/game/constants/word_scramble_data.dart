// Dữ liệu từ vựng dành cho trò chơi Word Scramble.
// Mỗi mục gồm:
//   - [word]       : từ tiếng Anh cần sắp xếp lại (hoặc câu cần sắp xếp cho mức Hard)
//   - [hint]       : gợi ý bằng tiếng Việt
//   - [difficulty] : mức độ khó ('easy' | 'medium' | 'hard')

class WordScrambleItem {
  final String word;
  final String hint;
  final String difficulty;

  const WordScrambleItem({
    required this.word,
    required this.hint,
    required this.difficulty,
  });
}

const List<WordScrambleItem> wordScrambleData = [
  // ─── EASY (3-5 ký tự) ───────────────────────────────────────────────────────
  WordScrambleItem(
    word: 'water',
    hint: 'Chất lỏng không màu, không mùi, rất cần thiết cho sự sống trên Trái Đất!',
    difficulty: 'easy',
  ),
  WordScrambleItem(
    word: 'tree',
    hint: 'Sinh vật có thân gỗ, mang lại bóng mát và oxy cho chúng ta!',
    difficulty: 'easy',
  ),
  WordScrambleItem(
    word: 'book',
    hint: 'Nơi lưu giữ tri thức, bạn có thể mở ra và đọc nó mỗi ngày!',
    difficulty: 'easy',
  ),
  WordScrambleItem(
    word: 'sun',
    hint: 'Ngôi sao sáng nhất vào ban ngày, mang lại ánh sáng và sự ấm áp!',
    difficulty: 'easy',
  ),
  WordScrambleItem(
    word: 'fire',
    hint: 'Một hiện tượng tỏa nhiệt và ánh sáng, dùng để nấu chín thức ăn!',
    difficulty: 'easy',
  ),
  WordScrambleItem(
    word: 'bird',
    hint: 'Loài vật có cánh, thường bay lượn trên bầu trời và hót líu lo!',
    difficulty: 'easy',
  ),
  WordScrambleItem(
    word: 'fish',
    hint: 'Loài động vật có vảy, sống dưới nước và thở bằng mang!',
    difficulty: 'easy',
  ),
  WordScrambleItem(
    word: 'star',
    hint: 'Những điểm sáng lấp lánh trên bầu trời đêm tăm tối!',
    difficulty: 'easy',
  ),
  WordScrambleItem(
    word: 'moon',
    hint: 'Vệ tinh tự nhiên của Trái Đất, tỏa sáng dịu nhẹ vào ban đêm!',
    difficulty: 'easy',
  ),
  WordScrambleItem(
    word: 'rain',
    hint: 'Những giọt nước rơi từ đám mây xuống làm ướt mặt đất!',
    difficulty: 'easy',
  ),
  WordScrambleItem(
    word: 'wind',
    hint: 'Luồng không khí di chuyển, bạn có thể cảm nhận nhưng không thể nhìn thấy!',
    difficulty: 'easy',
  ),
  WordScrambleItem(
    word: 'snow',
    hint: 'Những tinh thể băng trắng buốt rơi xuống vào mùa đông lạnh giá!',
    difficulty: 'easy',
  ),
  WordScrambleItem(
    word: 'time',
    hint: 'Thứ mà trôi qua không bao giờ quay lại, chúng ta đo nó bằng đồng hồ!',
    difficulty: 'easy',
  ),
  WordScrambleItem(
    word: 'love',
    hint: 'Một cảm xúc vô cùng tuyệt vời khi bạn dành tình cảm sâu đậm cho ai đó!',
    difficulty: 'easy',
  ),
  WordScrambleItem(
    word: 'food',
    hint: 'Thứ mà chúng ta ăn hàng ngày để nạp năng lượng sinh sống!',
    difficulty: 'easy',
  ),
  WordScrambleItem(
    word: 'door',
    hint: 'Vật dùng để đóng mở lối ra vào của một căn phòng hoặc ngôi nhà!',
    difficulty: 'easy',
  ),
  WordScrambleItem(
    word: 'city',
    hint: 'Một khu vực rộng lớn nơi có rất đông người sinh sống và làm việc!',
    difficulty: 'easy',
  ),
  WordScrambleItem(
    word: 'road',
    hint: 'Con đường được trải nhựa để các phương tiện giao thông di chuyển dễ dàng!',
    difficulty: 'easy',
  ),
  WordScrambleItem(
    word: 'song',
    hint: 'Một bản nhạc có lời ca giai điệu mà bạn có thể hát theo!',
    difficulty: 'easy',
  ),
  WordScrambleItem(
    word: 'game',
    hint: 'Một hoạt động giải trí có luật lệ để mọi người cùng chơi đùa!',
    difficulty: 'easy',
  ),

  // ─── MEDIUM (6-10 ký tự) ────────────────────────────────────────────────────
  WordScrambleItem(
    word: 'pollution',
    hint: 'Điều này sẽ ảnh hưởng rất xấu đến môi trường sống của chúng ta!',
    difficulty: 'medium',
  ),
  WordScrambleItem(
    word: 'hospital',
    hint: 'Nơi bạn sẽ đến để được các y bác sĩ chăm sóc khi bị ốm đau!',
    difficulty: 'medium',
  ),
  WordScrambleItem(
    word: 'computer',
    hint: 'Cỗ máy điện tử thông minh giúp chúng ta làm việc và giải trí hàng ngày!',
    difficulty: 'medium',
  ),
  WordScrambleItem(
    word: 'internet',
    hint: 'Mạng lưới toàn cầu kết nối hàng triệu máy tính lại với nhau!',
    difficulty: 'medium',
  ),
  WordScrambleItem(
    word: 'mountain',
    hint: 'Khối đất đá khổng lồ nhô cao lên khỏi mặt đất, rất khó để leo lên đỉnh!',
    difficulty: 'medium',
  ),
  WordScrambleItem(
    word: 'airplane',
    hint: 'Phương tiện giao thông có thể bay trên bầu trời để chở hàng trăm hành khách!',
    difficulty: 'medium',
  ),
  WordScrambleItem(
    word: 'elephant',
    hint: 'Loài động vật trên cạn lớn nhất với cái vòi rất dài và đôi tai to!',
    difficulty: 'medium',
  ),
  WordScrambleItem(
    word: 'universe',
    hint: 'Không gian bao la chứa vô số các thiên hà và các vì sao xa xôi!',
    difficulty: 'medium',
  ),
  WordScrambleItem(
    word: 'password',
    hint: 'Dãy ký tự bí mật dùng để bảo vệ tài khoản của bạn khỏi người lạ!',
    difficulty: 'medium',
  ),
  WordScrambleItem(
    word: 'library',
    hint: 'Nơi có rất nhiều kệ sách để bạn đến mượn và đọc trong tĩnh lặng!',
    difficulty: 'medium',
  ),
  WordScrambleItem(
    word: 'football',
    hint: 'Môn thể thao vua sử dụng đôi chân để đưa bóng vào lưới đối phương!',
    difficulty: 'medium',
  ),
  WordScrambleItem(
    word: 'vacation',
    hint: 'Khoảng thời gian nghỉ ngơi, đi du lịch để thư giãn sau những ngày làm việc!',
    difficulty: 'medium',
  ),
  WordScrambleItem(
    word: 'umbrella',
    hint: 'Vật dụng rất hữu ích giúp bạn không bị ướt khi trời bất chợt đổ mưa!',
    difficulty: 'medium',
  ),
  WordScrambleItem(
    word: 'keyboard',
    hint: 'Bảng điều khiển gồm nhiều nút bấm để nhập chữ và số vào máy tính!',
    difficulty: 'medium',
  ),
  WordScrambleItem(
    word: 'calendar',
    hint: 'Công cụ giúp chúng ta theo dõi và biết được hôm nay là ngày tháng năm nào!',
    difficulty: 'medium',
  ),
  WordScrambleItem(
    word: 'sunlight',
    hint: 'Nguồn năng lượng rực rỡ và ấm áp tỏa ra từ Mặt Trời vào ban ngày!',
    difficulty: 'medium',
  ),
  WordScrambleItem(
    word: 'necklace',
    hint: 'Một món đồ trang sức rất đẹp và đắt tiền thường được đeo ở trên cổ!',
    difficulty: 'medium',
  ),
  WordScrambleItem(
    word: 'shoulder',
    hint: 'Bộ phận trên cơ thể kết nối giữa cánh tay và phần trên của thân người!',
    difficulty: 'medium',
  ),
  WordScrambleItem(
    word: 'champion',
    hint: 'Người đã xuất sắc vượt qua tất cả đối thủ để giành vị trí cao nhất!',
    difficulty: 'medium',
  ),
  WordScrambleItem(
    word: 'dinosaur',
    hint: 'Loài bò sát khổng lồ đã tuyệt chủng từ rất lâu trên Trái Đất!',
    difficulty: 'medium',
  ),

  // ─── HARD (Sắp xếp câu/cụm từ) ──────────────────────────────────────────────
  WordScrambleItem(
    word: 'having completed / the project ahead of schedule / the team / received praise',
    hint: '',
    difficulty: 'hard',
  ),
  WordScrambleItem(
    word: 'exhausted by the long journey / he / fell asleep immediately',
    hint: '',
    difficulty: 'hard',
  ),
  WordScrambleItem(
    word: 'being aware of the risks / she / decided / not to invest',
    hint: '',
    difficulty: 'hard',
  ),
  WordScrambleItem(
    word: 'having been warned several times / they / finally changed their behavior',
    hint: '',
    difficulty: 'hard',
  ),
  WordScrambleItem(
    word: 'surrounded by mountains / the village / attracts many tourists',
    hint: '',
    difficulty: 'hard',
  ),
  WordScrambleItem(
    word: 'eager to learn new skills / the students / paid close attention / to the teacher',
    hint: '',
    difficulty: 'hard',
  ),
  WordScrambleItem(
    word: 'deeply moved by the story / everyone / in the room / shed a tear',
    hint: '',
    difficulty: 'hard',
  ),
  WordScrambleItem(
    word: 'working day and night / the scientists / finally discovered / a new cure',
    hint: '',
    difficulty: 'hard',
  ),
  WordScrambleItem(
    word: 'impressed by her performance / the manager / offered her / a promotion',
    hint: '',
    difficulty: 'hard',
  ),
  WordScrambleItem(
    word: 'not knowing what to do / the little boy / stood crying / in the street',
    hint: '',
    difficulty: 'hard',
  ),
  WordScrambleItem(
    word: 'hoping for a better future / many people / migrated / to the city',
    hint: '',
    difficulty: 'hard',
  ),
  WordScrambleItem(
    word: 'frightened by the loud noise / the dog / hid under / the table',
    hint: '',
    difficulty: 'hard',
  ),
  WordScrambleItem(
    word: 'completely destroyed by the storm / the old house / had to be rebuilt',
    hint: '',
    difficulty: 'hard',
  ),
  WordScrambleItem(
    word: 'determined to win the race / he / trained hard / every single day',
    hint: '',
    difficulty: 'hard',
  ),
  WordScrambleItem(
    word: 'looking through the window / she / saw / a beautiful rainbow',
    hint: '',
    difficulty: 'hard',
  ),
  WordScrambleItem(
    word: 'written in ancient times / the manuscript / was difficult / to translate',
    hint: '',
    difficulty: 'hard',
  ),
  WordScrambleItem(
    word: 'carefully planned in advance / the event / was a huge success',
    hint: '',
    difficulty: 'hard',
  ),
  WordScrambleItem(
    word: 'trying to catch the bus / he / ran as fast as / he could',
    hint: '',
    difficulty: 'hard',
  ),
  WordScrambleItem(
    word: 'disappointed with the results / the coach / organized / an extra training session',
    hint: '',
    difficulty: 'hard',
  ),
  WordScrambleItem(
    word: 'hidden behind the clouds / the moon / cast a dim light / on the path',
    hint: '',
    difficulty: 'hard',
  ),
  WordScrambleItem(
    word: 'motivated by his words / the team / worked harder / than ever before',
    hint: '',
    difficulty: 'hard',
  ),
  WordScrambleItem(
    word: 'carrying a heavy backpack / the hiker / slowly climbed / the steep hill',
    hint: '',
    difficulty: 'hard',
  ),
  WordScrambleItem(
    word: 'confused by the complicated instructions / the customers / asked for help',
    hint: '',
    difficulty: 'hard',
  ),
  WordScrambleItem(
    word: 'looking forward to the holiday / the children / packed their bags / happily',
    hint: '',
    difficulty: 'hard',
  ),
  WordScrambleItem(
    word: 'amazed by the magic trick / the audience / clapped their hands / loudly',
    hint: '',
    difficulty: 'hard',
  ),
  WordScrambleItem(
    word: 'designed by a famous architect / the new museum / attracted / many visitors',
    hint: '',
    difficulty: 'hard',
  ),
  WordScrambleItem(
    word: 'feeling tired after work / she / decided to stay home / and relax',
    hint: '',
    difficulty: 'hard',
  ),
  WordScrambleItem(
    word: 'painted in bright colors / the playground / looked very inviting',
    hint: '',
    difficulty: 'hard',
  ),
  WordScrambleItem(
    word: 'listening to her favorite song / she / forgot all about / her worries',
    hint: '',
    difficulty: 'hard',
  ),
  WordScrambleItem(
    word: 'trapped in the elevator / they / waited patiently / for rescue',
    hint: '',
    difficulty: 'hard',
  ),
];
