# <div align="center">📧 AI Email Manager — PROD</div>

<div align="center">
  <p><strong>Hệ thống quản lý email thông minh tích hợp AI, triển khai trên GCP với kiến trúc 3-tier bảo mật cao</strong></p>
  <p>Tự động hóa toàn bộ luồng xử lý: Đồng bộ Gmail thời gian thực ⚡ Phân loại & Tóm tắt bằng AI 🤖 Truy vấn ngữ nghĩa (RAG) 💬 Tương tác phản hồi trực tiếp qua Discord Bot 🔔</p>
</div>

<div align="center">

[![FastAPI](https://img.shields.io/badge/FastAPI-0.115-009688?style=for-the-badge&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)
[![Next.js](https://img.shields.io/badge/Next.js-14.2-000000?style=for-the-badge&logo=next.js&logoColor=white)](https://nextjs.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15%2B-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![OpenAI](https://img.shields.io/badge/OpenAI-GPT--4o%20%2F%20mini-412991?style=for-the-badge&logo=openai&logoColor=white)](https://openai.com/)
[![GCP](https://img.shields.io/badge/GCP-Cloud%20Platform-4285F4?style=for-the-badge&logo=google-cloud&logoColor=white)](https://cloud.google.com/)
[![Terraform](https://img.shields.io/badge/Terraform-IaC-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)](https://www.terraform.io/)

</div>

---

## 🌐 Hệ Thống Triển Khai (PROD)

| Dịch vụ | Địa chỉ URL | Trạng thái |
| :--- | :--- | :--- |
| **Giao diện người dùng (Frontend)** | [https://emailagent.ddnsfree.com](https://emailagent.ddnsfree.com) | `PROD` |
| **Tài liệu API (Swagger Docs)** | [https://emailagent.ddnsfree.com/docs](https://emailagent.ddnsfree.com/docs) | `Development only` |

---

## 🏗️ Kiến Trúc Tổng Thể (GCP 3-Tier)

```
Internet
    │
    ▼
┌────────────────────────────────────────────────────────┐
│             Cloud Armor WAF                            │
│   (Chống DDoS, SQL Injection, XSS, Rate Limiting)      │
└────────────────────┬───────────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────┐
│    Global HTTPS Load Balancer + Cloud CDN + SSL/TLS    │
│              IP: 136.68.154.239                        │
│         emailagent.ddnsfree.com                        │
└──────────────┬─────────────────────────────────────────┘
               │
   ┌───────────┴───────────┐
   │                       │
   ▼                       ▼
Web Subnet             App Subnet
   │                       │
   ▼                       ▼
API VM (MIG)          Worker VM
FastAPI :3001         Background Jobs
Autoscaler 1-3 VM     Email Sync, Discord
   │                       │
   └───────────┬───────────┘
               │
               ▼
          DB Subnet
               │
               ▼
┌──────────────────────────────────────┐
│   Cloud SQL PostgreSQL 15            │
│   Private IP: 10.83.0.3             │
│   (Không truy cập được từ Internet) │
└──────────────────────────────────────┘

Dịch vụ quản lý bổ trợ (GCP):
  ├── Secret Manager      — Lưu trữ API keys, tokens, mật khẩu
  ├── Cloud Pub/Sub       — Nhận thông báo Gmail real-time
  └── Identity Platform   — Xác thực người dùng (Email/Password)

Dịch vụ bên ngoài (External APIs):
  ├── Gmail API      — Đọc / Gửi / Gắn nhãn email
  ├── OpenAI API     — GPT-4o (phân loại, tóm tắt, chat, soạn thảo)
  └── Discord API    — Thông báo + Bot tương tác
```

---

## 🎨 Sơ Đồ Luồng Hoạt Động

### 🔄 Luồng Đồng bộ & Phân loại Email

```mermaid
sequenceDiagram
    autonumber
    participant Gmail as Gmail API
    participant PubSub as Cloud Pub/Sub
    participant Worker as Worker VM
    participant DB as Cloud SQL
    participant OpenAI as OpenAI API
    participant Discord as Discord Bot

    Note over Worker: Gmail Pub/Sub Webhook hoặc Fallback polling mỗi 90s
    PubSub->>Worker: Thông báo email mới (push notification)
    Worker->>DB: Lấy OAuth token & history_id
    Worker->>Gmail: Gọi History API (Incremental Sync)
    Gmail-->>Worker: Danh sách email mới
    Worker->>DB: Lưu email thô vào bảng 'emails'

    Worker->>OpenAI: Gửi nội dung email (Phân loại, Tóm tắt, Ưu tiên)
    OpenAI-->>Worker: JSON {category, priority, summary, suggestion}
    Worker->>DB: Cập nhật category, priority, summary
    Worker->>Gmail: Gắn Label AI lên Gmail thật

    Worker->>OpenAI: Sinh Vector Embedding (1536 chiều)
    OpenAI-->>Worker: Vector float[]
    Worker->>DB: Lưu vào bảng 'email_embeddings' (pgvector)

    Worker->>Discord: Gửi thông báo tóm tắt email
```

### 💬 Luồng RAG Chat (AI Chatbot)

```mermaid
sequenceDiagram
    autonumber
    actor User as Người dùng
    participant API as API VM (FastAPI)
    participant DB as Cloud SQL (pgvector)
    participant OpenAI as OpenAI API

    User->>API: Gửi câu hỏi qua /ai/chat
    API->>OpenAI: Phân tích intent (Intent Detection)
    API->>OpenAI: Sinh vector cho câu hỏi
    API->>DB: Tìm kiếm cosine similarity trên email_embeddings
    DB-->>API: Top 5 email liên quan nhất
    API->>OpenAI: System prompt + Context + Lịch sử chat + Câu hỏi
    OpenAI-->>API: Câu trả lời tiếng Việt
    API->>DB: Lưu lịch sử tin nhắn (ai_chat_messages)
    API-->>User: Câu trả lời + nguồn email (sources)
```

### 🔑 Luồng Gmail OAuth2

```mermaid
sequenceDiagram
    autonumber
    actor User as Người dùng
    participant API as API VM (FastAPI)
    participant DB as Cloud SQL
    participant Google as Google OAuth

    User->>API: Yêu cầu URL xác thực
    API->>API: Tạo PKCE code_verifier & state
    API-->>User: Trả về Google Auth URL
    User->>Google: Đăng nhập & cấp quyền Gmail
    Google->>API: Callback với code & state
    API->>Google: Đổi code lấy Access + Refresh Token
    API->>DB: Mã hóa Fernet & lưu vào 'gmail_accounts'

    Note over API,Google: Auto-Refresh Token trước mỗi lần gọi API
    API->>DB: Kiểm tra token_expiry
    alt Token hết hạn
        API->>Google: Dùng Refresh Token xin token mới
        API->>DB: Cập nhật Access Token mới (đã mã hóa)
    end
```

---

## 🚀 Tính Năng Chính

### 1. Đồng Bộ Gmail Thông Minh
- **Incremental Sync (History API)**: Chỉ tải email mới dựa trên `history_id` — cực nhanh (~200ms)
- **Dual Sync**: Gmail Pub/Sub webhook (real-time) kết hợp với fallback polling mỗi 90s
- **Auto Watch Renewal**: Tự động gia hạn Gmail Watch mỗi 12 giờ (Watch có TTL 7 ngày)
- **Parallel Async Fetch**: `asyncio.gather` và `asyncio.to_thread` — tải 50-100 email trong < 1.5 giây

### 2. Trợ Lý AI (GPT-4o)
- **Phân loại tự động**: `work`, `personal`, `invoice`, `promotion`, `security`, `social`, `other`
- **Độ ưu tiên**: `high`, `medium`, `low` + cảm xúc `positive`, `neutral`, `negative`
- **Tóm tắt tiếng Việt** + đề xuất hành động cụ thể
- **Gắn nhãn Gmail thật**: Kết quả AI được đồng bộ ngược lại thành Label trên Gmail

### 3. RAG Chat — Hỏi Đáp Thông Minh
- **Vector search**: Cosine similarity trên `pgvector` — tìm 5 email liên quan nhất
- **Context-aware**: Kết hợp lịch sử chat (session) + email context vào prompt
- **Intent Detection**: Phân tích ý định câu hỏi trước khi trả lời
- **Token budget**: Tự động giới hạn context để không vượt quá giới hạn token của model

### 4. Discord Bot
- Nhận thông báo email mới tức thì với tóm tắt AI
- Chat trực tiếp với AI qua Discord (`@bot <câu hỏi>`)
- Soạn thảo và gửi email phản hồi ngay trong Discord (nút **Send** / **Edit** / **Cancel**)
- Auto-reconnect với exponential backoff khi mất kết nối

### 5. Bảo Mật Nhiều Lớp
- **Cloud Armor WAF**: Chống DDoS, SQL Injection, XSS ở tầng Load Balancer
- **Secret Manager**: Toàn bộ API keys & tokens lưu trên GCP Secret Manager — không có gì trong code
- **Fernet AES-256**: Mã hóa OAuth token trước khi lưu DB
- **PKCE OAuth2**: Bảo vệ luồng xác thực Gmail
- **Rate Limiting**: SlowAPI giới hạn request trên tất cả endpoint
- **Prompt Injection Detection**: Chặn các câu lệnh tấn công AI bằng cả tiếng Anh và tiếng Việt

---

## 🗄️ Cấu Trúc Database

| Bảng | Mô tả |
|---|---|
| `users` | Thông tin người dùng (Firebase UID) |
| `gmail_accounts` | OAuth tokens Gmail (mã hóa Fernet) |
| `discord_accounts` | Thông tin kết nối Discord Bot |
| `emails` | Nội dung email + kết quả phân loại AI |
| `email_embeddings` | Vector 1536 chiều (pgvector) |
| `labels` | Nhãn Gmail của người dùng |
| `ai_chat_sessions` | Phiên chat AI |
| `ai_chat_messages` | Lịch sử tin nhắn (role: user/assistant) |
| `notifications` | Log thông báo Discord đã gửi |
| `user_integrations` | Trạng thái kết nối gmail/discord |

---

## 📁 Cấu Trúc Project

```
.
├── backend/
│   ├── app/
│   │   ├── main.py              # FastAPI app, lifespan, middleware
│   │   ├── config.py            # Pydantic Settings (biến môi trường)
│   │   ├── database.py          # AsyncEngine, AsyncSession
│   │   ├── models.py            # SQLAlchemy ORM models
│   │   ├── dependencies.py      # Auth middleware (Firebase token verify)
│   │   ├── routers/
│   │   │   ├── ai.py            # /ai/chat, /ai/draft, /ai/send
│   │   │   ├── emails.py        # /emails (CRUD + sync)
│   │   │   ├── gmail.py         # /gmail (OAuth, webhook, watch)
│   │   │   ├── discord.py       # /discord (OAuth, notifications)
│   │   │   └── labels.py        # /labels
│   │   ├── services/
│   │   │   ├── ai_service.py    # GPT-4o chat, classify, embed, RAG
│   │   │   ├── gmail_service.py # Gmail API (fetch, send, labels, watch)
│   │   │   ├── discord_bot.py   # Discord Gateway bot
│   │   │   └── firebase_service.py # Firebase token verify
│   │   └── utils/
│   │       ├── crypto.py        # Fernet encrypt/decrypt
│   │       └── limiter.py       # SlowAPI rate limiter
│   ├── requirements.txt
│   ├── run.py                   # Entry point API server (uvicorn)
│   └── run_worker.py            # Entry point Worker (background jobs)
├── frontend/                    # Next.js app (TypeScript)
├── migrations/
│   └── 001_init_schema.sql      # Schema SQL (pgvector, indexes, triggers)
└── terraform/                   # Hạ tầng GCP (Infrastructure as Code)
    ├── vpc/                     # Mạng VPC, Subnet, Cloud NAT
    ├── database/                # Cloud SQL PostgreSQL 15
    └── compute/                 # VM, MIG, Load Balancer, WAF, CDN, Secrets
```

---

## ⚙️ Cài Đặt Local

### Yêu Cầu
- Python 3.11+
- Node.js 18+
- PostgreSQL 15+ với extension `pgvector`
- Tài khoản: Google Cloud, OpenAI, Discord Developer

### 1. Cài PostgreSQL + pgvector (Ubuntu/Debian)

```bash
sudo apt install postgresql postgresql-contrib postgresql-server-dev-15

# Cài pgvector
git clone https://github.com/pgvector/pgvector.git
cd pgvector && make && sudo make install

# Tạo database
sudo -u postgres psql -c "CREATE DATABASE ai_email_manager;"
sudo -u postgres psql -c "CREATE USER postgres WITH PASSWORD 'yourpassword';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ai_email_manager TO postgres;"
```

### 2. Cấu hình Backend (.env)

Tạo file `backend/.env`:

```env
PORT=3001
ENVIRONMENT=development

DATABASE_URL=postgresql+asyncpg://postgres:yourpassword@localhost:5432/ai_email_manager
DATABASE_URL_SYNC=postgresql+psycopg2://postgres:yourpassword@localhost:5432/ai_email_manager

OPENAI_API_KEY=sk-proj-your-api-key-here
OPENAI_MODEL=gpt-4o
OPENAI_EMBEDDING_MODEL=text-embedding-3-small

GOOGLE_CLIENT_ID=your-google-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-google-client-secret
GOOGLE_REDIRECT_URI=http://localhost:3001/gmail/callback
GMAIL_PUBSUB_TOPIC=projects/your-gcp-project/topics/gmail-notifications

# Sinh key: python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
ENCRYPTION_KEY=your-generated-fernet-key-here

DISCORD_CLIENT_ID=your-discord-client-id
DISCORD_CLIENT_SECRET=your-discord-client-secret
DISCORD_REDIRECT_URI=http://localhost:3001/discord/callback
DISCORD_BOT_TOKEN=your-discord-bot-token

CORS_ORIGINS=http://localhost:3000
FRONTEND_URL=http://localhost:3000
```

### 3. Chạy Migration & Backend

```bash
cd backend
python3 -m venv venv
source venv/bin/activate      # Linux/Mac
venv\Scripts\activate         # Windows

pip install -r requirements.txt

# Tạo bảng database
python -m app.run_migration

# Khởi động API server
python run.py

# Khởi động Worker (cửa sổ terminal khác)
python run_worker.py
```

### 4. Chạy Frontend

```bash
cd frontend
npm install
npm run dev
```

---

## 🌐 Triển Khai Trên GCP

### Yêu Cầu
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) đã cài đặt và xác thực
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.6.0

### Bước 1: Xác thực GCP

```bash
gcloud auth login
gcloud auth application-default login
gcloud auth application-default set-quota-project YOUR_GCP_PROJECT_ID
```

### Bước 2: Cấu hình biến môi trường

```bash
cp terraform/vpc/terraform.tfvars.example      terraform/vpc/terraform.tfvars
cp terraform/database/terraform.tfvars.example terraform/database/terraform.tfvars
cp terraform/compute/terraform.tfvars.example  terraform/compute/terraform.tfvars

# Điền các giá trị thực tế vào 3 file .tfvars vừa tạo
```

### Bước 3: Triển khai theo thứ tự

```bash
# 1. Tạo mạng VPC
cd terraform/vpc
terraform init && terraform apply

# 2. Tạo Cloud SQL (cập nhật vpc_id từ output bước 1 vào tfvars)
cd ../database
terraform init && terraform apply

# 3. Tạo máy chủ & Load Balancer (cập nhật db_private_ip từ output bước 2 vào tfvars)
cd ../compute
terraform init && terraform apply
```

### Bước 4: Cấu hình DNS

```bash
# Lấy IP Load Balancer từ output
terraform output load_balancer_ip
```

Trỏ **A Record** tên miền về địa chỉ IP này. SSL sẽ được tự động cấp trong vòng 5–15 phút.

---

## 🛡️ Bảo Mật

> [!IMPORTANT]
> - **Cloud Armor WAF**: Bảo vệ tầng Load Balancer chống DDoS, SQLi, XSS, Bad Bot
> - **Secret Manager**: Access Token, Refresh Token, API keys — không có thông tin nhạy cảm nào trong source code
> - **Encryption-at-Rest**: OAuth tokens được mã hóa AES-256 (Fernet) trước khi ghi DB
> - **Private Database**: Cloud SQL chỉ có Private IP, không thể truy cập trực tiếp từ Internet
> - **PKCE OAuth2**: Bảo vệ luồng xác thực Gmail chống Authorization Code Interception
> - **Prompt Injection Shield**: Chặn các câu lệnh tấn công AI bằng tiếng Anh và tiếng Việt

---

<div align="center">
  Được phát triển với ❤️ bởi <strong>Khanh</strong>
</div>
