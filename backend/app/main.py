import os
os.environ['OAUTHLIB_RELAX_TOKEN_SCOPE'] = '1'

import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.config import settings
from app.services.firebase_service import init_firebase
from app.routers import emails, ai, gmail, labels, user, discord, drafts
import asyncio
import datetime
from sqlalchemy import select
from app.database import AsyncSessionLocal
from app.models import GmailAccount, Email
from app.services.gmail_service import fetch_emails_incremental, fetch_recent_emails
from app.services.ai_service import classify_and_summarize
from app.utils.notification_helper import send_notifications_for_email

logging.basicConfig(
    level=logging.INFO if settings.ENVIRONMENT == "development" else logging.WARNING,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info("🚀 AI Email Manager Backend starting...")
    init_firebase()
    logger.info("✅ Firebase Admin initialized")
    
    yield
    # Shutdown
    logger.info("🛑 Backend shutting down...")




app = FastAPI(
    title="AI Email Manager API",
    description="Backend API for AI Email Manager SaaS — Gmail AI, RAG Chat, Notifications",
    version="1.0.0",
    docs_url="/docs" if settings.ENVIRONMENT != "production" else None,
    redoc_url="/redoc" if settings.ENVIRONMENT != "production" else None,
    lifespan=lifespan,
)

from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from app.utils.limiter import limiter

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# ─── CORS ───────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "Accept"],
)

# ─── Security Headers Middleware ────────────────────────────────
# NOTE: Main security headers (CSP, HSTS, X-Frame-Options) are handled by Nginx.
# This middleware only adds API-specific headers that Nginx does not set.
@app.middleware("http")
async def add_security_headers(request, call_next):
    # Giới hạn kích thước request body (Chống DoS)
    content_length = request.headers.get("content-length")
    if content_length:
        if int(content_length) > 10 * 1024 * 1024:  # 10 MB
            from fastapi.responses import JSONResponse
            return JSONResponse(status_code=413, content={"detail": "Request entity too large"})

    response = await call_next(request)
    # Ngăn trình duyệt tự ý đoán kiểu tệp tin sai lệch (Chống MIME Sniffing)
    response.headers["X-Content-Type-Options"] = "nosniff"
    # Content Security Policy chống XSS (cho phép 'unsafe-inline' cho script để các popup OAuth có thể đóng và gửi message)
    response.headers["Content-Security-Policy"] = "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:;"
    # Ẩn thông tin framework backend khỏi attacker
    if "X-Powered-By" in response.headers:
        del response.headers["X-Powered-By"]
    if "Server" in response.headers:
        del response.headers["Server"]
    return response

# ─── Routers ────────────────────────────────────────────────────
app.include_router(emails.router)
app.include_router(ai.router)
app.include_router(gmail.router)
app.include_router(labels.router)
app.include_router(user.router)
app.include_router(discord.router)
app.include_router(drafts.router)


# ─── Health check ───────────────────────────────────────────────
@app.get("/health", tags=["Health"])
async def health():
    return {
        "status": "ok",
        "service": "AI Email Manager Backend",
        "version": "1.0.0",
        "environment": settings.ENVIRONMENT,
    }


@app.get("/", tags=["Health"])
async def root():
    return {
        "message": "AI Email Manager API",
        "docs": "/docs",
        "health": "/health",
    }
