## Cài đặt và chạy n8n
Khởi động n8n 
```bash
docker compose --profile cpu up
```

Cho phép n8n chạy với ngrok
```bash
ngrok http --url=xxxxxxxx.ngrok-free.app 5678      # Copy url from ngrok
```

Thêm webhook vào docker-composer.yml
```bash
x-n8n: &service-n8n
  image: n8nio/n8n:latest
  networks: ['demo']
  environment:
    - DB_TYPE=postgresdb
    - DB_POSTGRESDB_HOST=postgres
    - DB_POSTGRESDB_USER=${POSTGRES_USER}
    - DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
    - N8N_DIAGNOSTICS_ENABLED=false
    - N8N_PERSONALIZATION_ENABLED=false
    - N8N_ENCRYPTION_KEY
    - N8N_USER_MANAGEMENT_JWT_SECRET
    - OLLAMA_HOST=ollama:11434
    - WEBHOOK_URL="https://xxxxxxxx.ngrok-free.app" #for Ngrok
```

## Một số liên kết hay sử dụng trong khi training
```bash
Google: https://console.cloud.google.com/
Claude: https://console.anthropic.com/settings/keys
ChatGPT: https://platform.openai.com/api-keys
Assemblyai: https://www.assemblyai.com/dashboard/api-keys
Gemini: https://aistudio.google.com/app/apikey
```

## Sử dụng assemblyai

Đăng ký tài khoản với assemblyai

```bash
#!/bin/bash

# ⚙️ Cấu hình
TELEGRAM_TOKEN=""
TELEGRAM_PATH="{{ $json["result"]["file_path"] }}"
TELEGRAM_URL="https://api.telegram.org/file/bot$TELEGRAM_TOKEN/$TELEGRAM_PATH"
ASSEMBLYAI_TOKEN=""

# 🌐 1. Upload file audio lên AssemblyAI (dùng stream từ Telegram)
UPLOAD_RESPONSE=$(curl -s \
  --request POST \
  --header "authorization: $ASSEMBLYAI_TOKEN" \
  --data-binary @<(curl -s "$TELEGRAM_URL") \
  "https://api.assemblyai.com/v2/upload")

UPLOAD_URL=$(echo "$UPLOAD_RESPONSE" | jq -r '.upload_url')

if [[ "$UPLOAD_URL" == "null" || -z "$UPLOAD_URL" ]]; then
  echo "{\"error\": \"Không upload được file lên AssemblyAI\"}"
  exit 1
fi

# 📝 2. Gửi yêu cầu transcription
TRANSCRIBE_RESPONSE=$(curl -s \
  --request POST \
  --header "authorization: $ASSEMBLYAI_TOKEN" \
  --header "content-type: application/json" \
  --data "{\"audio_url\": \"$UPLOAD_URL\", \"language_code\": \"vi\"}" \
  "https://api.assemblyai.com/v2/transcript")

TRANSCRIPT_ID=$(echo "$TRANSCRIBE_RESPONSE" | jq -r '.id')

if [[ "$TRANSCRIPT_ID" == "null" || -z "$TRANSCRIPT_ID" ]]; then
  echo "{\"error\": \"Không tạo được transcript\"}"
  exit 1
fi

# ⏳ 3. Chờ transcript hoàn tất (poll mỗi 3s)
TRANSCRIPT_STATUS=""
while true; do
  STATUS_RESPONSE=$(curl -s \
    --request GET \
    --header "authorization: $ASSEMBLYAI_TOKEN" \
    "https://api.assemblyai.com/v2/transcript/$TRANSCRIPT_ID")

  TRANSCRIPT_STATUS=$(echo "$STATUS_RESPONSE" | jq -r '.status')

  if [[ "$TRANSCRIPT_STATUS" == "completed" ]]; then
    TEXT=$(echo "$STATUS_RESPONSE" | jq -r '.text')
    echo \"$TEXT\"
    exit 0
  elif [[ "$TRANSCRIPT_STATUS" == "error" ]]; then
    echo "{\"error\": \"AssemblyAI báo lỗi: $(echo "$STATUS_RESPONSE" | jq -r '.error')\"}"
    exit 1
  else
    sleep 3
  fi
done
```

## Cài đặt Whishper
Truy cập vao Colab: https://colab.research.google.com/
 
1. Cài đặt ffmpeg, Whisper, Flask và ngrok
```bash 
!apt-get install ffmpeg
!pip install git+https://github.com/openai/whisper.git
!pip install flask pyngrok
```

2. Cấu hinh Ngrok cho Colab
```bash
!ngrok authtoken YOUR_AUTH_TOKEN
```

3. Tạo API Whisper
```python
from flask import Flask, request, jsonify
import whisper
import os
from pyngrok import ngrok
import threading

app = Flask(__name__)
model = whisper.load_model("base")  # Mô hình nhẹ, phù hợp với Colab

@app.route("/transcribe", methods=["POST"])
def transcribe():
    try:
        # Kiểm tra file âm thanh
        if "audio" not in request.files:
            return jsonify({"error": "No audio file provided"}), 400
        
        audio_file = request.files["audio"]
        temp_path = "temp_audio.mp3"
        audio_file.save(temp_path)  # Lưu file tạm thời

        # Chuyển đổi âm thanh thành văn bản
        result = model.transcribe(temp_path, language="vi")  # Chỉ định tiếng Việt
        text = result["text"]

        # Xóa file tạm thời
        os.remove(temp_path)

        return jsonify({"text": text})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# Chạy Flask trong một luồng riêng
def run_flask():
    app.run(host="0.0.0.0", port=5000)

# Khởi động ngrok để tạo URL công khai
public_url = ngrok.connect(5000)
print(f"Public URL: {public_url}")

# Chạy Flask
threading.Thread(target=run_flask, daemon=True).start()
```

4. Kiểm tra API
Sau khi chạy ô code trên, Colab sẽ in ra một Public URL (ví dụ: https://1234-34-56-78-90.ngrok-free.app)

Kiểm tra API bằng curl hoặc Postman từ máy tính của bạn
```bash
curl -X POST -F "audio=@/path/to/audio.mp3" https://1234-34-56-78-90.ngrok-free.app/transcribe
```

5. Code to download file từ Telegram và upload len Whisper
```bash
#!/bin/bash

# ⚙️ Cấu hình
API_WHISPER=""
TELEGRAM_TOKEN=""
FILE_ID="{{ $json.result.file_id }}"

# 🔍 Lấy TELEGRAM_PATH từ file_id
TELEGRAM_PATH=$(curl -s "https://api.telegram.org/bot$TELEGRAM_TOKEN/getFile?file_id=$FILE_ID" | jq -r '.result.file_path')

if [[ "$TELEGRAM_PATH" == "null" || -z "$TELEGRAM_PATH" ]]; then
  echo '{"success": false, "error": "Không tìm được file_path từ file_id."}'
  exit 1
fi

# 📥 Tải file về máy
TELEGRAM_URL="https://api.telegram.org/file/bot$TELEGRAM_TOKEN/$TELEGRAM_PATH"
LOCAL_FILE="./audio_downloaded.ogg"
curl -s -o "$LOCAL_FILE" "$TELEGRAM_URL"

if [[ ! -f "$LOCAL_FILE" ]]; then
  echo '{"success": false, "error": "Tải file không thành công."}'
  exit 1
fi

# 📤 Upload file tới API transcribe
TRANSCRIBE_RESPONSE=$(curl -s --form "audio=@$LOCAL_FILE" "$API_WHISPER/transcribe")

# 🧹 Option: Xóa file tạm
rm -f "$LOCAL_FILE"

# ✅ Trả về kết quả cuối cùng
echo "{\"success\": true, \"result\": $TRANSCRIBE_RESPONSE}" | jq
```