"""Background worker for running sync loops and Discord bot separately from the API server."""
import asyncio
import logging
import datetime
from sqlalchemy import select
from app.config import settings
from app.database import AsyncSessionLocal
from app.models import GmailAccount, Email
from app.services.firebase_service import init_firebase
from app.services.gmail_service import fetch_emails_incremental, fetch_recent_emails
from app.services.ai_service import classify_and_summarize
from app.utils.notification_helper import send_notifications_for_email

logging.basicConfig(
    level=logging.INFO if settings.ENVIRONMENT == "development" else logging.WARNING,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("worker")

async def gmail_watch_renewal_loop():
    logger.info("Starting Gmail watch renewal loop...")
    from app.services.gmail_service import renew_watch_for_all_users
    # Run immediately on startup
    try:
        async with AsyncSessionLocal() as db:
            await renew_watch_for_all_users(db)
    except Exception as e:
        logger.error(f"Initial Gmail watch renewal failed: {e}")

    while True:
        await asyncio.sleep(12 * 60 * 60)  # Run every 12 hours
        try:
            async with AsyncSessionLocal() as db:
                await renew_watch_for_all_users(db)
        except Exception as e:
            logger.error(f"Gmail watch renewal loop error: {e}")

async def auto_sync_loop():
    logger.info("Starting Auto-sync loop...")
    # Wait 30s after worker startup before first run
    await asyncio.sleep(30)

    while True:
        try:
            async with AsyncSessionLocal() as db:
                # Get all connected Gmail accounts
                result = await db.execute(
                    select(GmailAccount).where(GmailAccount.refresh_token.isnot(None))
                )
                accounts = result.scalars().all()

                for account in accounts:
                    try:
                        user_id = account.user_id

                        # Try incremental sync first, fall back to recent emails
                        emails_data = await fetch_emails_incremental(user_id, db)
                        if not emails_data:
                            if not account.history_id:
                                emails_data = await fetch_recent_emails(user_id, db, max_results=10)
                            else:
                                continue  # No new emails via incremental

                        new_count = 0
                        gmail_ids = [d["gmail_id"] for d in emails_data if d.get("gmail_id")]
                        existing_gmail_ids = set()
                        if gmail_ids:
                            result = await db.execute(
                                select(Email.gmail_id).where(
                                    Email.user_id == user_id,
                                    Email.gmail_id.in_(gmail_ids)
                                )
                            )
                            existing_gmail_ids = set(result.scalars().all())

                        added_gids = set()
                        newly_added_emails = []
                        for data in emails_data:
                            gid = data.get("gmail_id")
                            if not gid or gid in existing_gmail_ids or gid in added_gids:
                                continue

                            email = Email(user_id=user_id, **data)
                            db.add(email)
                            added_gids.add(gid)
                            newly_added_emails.append((email, data))
                            new_count += 1

                        if new_count > 0:
                            await db.commit()
                            await db.flush()
                            logger.info(f"Auto-sync: {new_count} new email(s) stored for user {user_id}")

                        # Run AI classification
                        for email, data in newly_added_emails:
                            try:
                                received_time = datetime.datetime.now(datetime.timezone.utc)
                                logger.info(f"Auto-sync: Email '{data.get('subject')}' received/synced at {received_time.isoformat()}")

                                ai_result = await classify_and_summarize(
                                    email.id,
                                    data.get("subject", ""),
                                    data.get("body_text", ""),
                                    db
                                )
                                # Send notifications
                                if ai_result:
                                    await send_notifications_for_email(user_id, email, ai_result, db)
                                    notified_time = datetime.datetime.now(datetime.timezone.utc)
                                    logger.info(f"Auto-sync: Notified for Email '{data.get('subject')}' at {notified_time.isoformat()}. Delay: {(notified_time - received_time).total_seconds()}s")
                            except Exception as ai_err:
                                await db.rollback()
                                logger.warning(f"Auto-sync AI classify failed for email '{data.get('subject')}': {ai_err}")

                    except Exception as user_err:
                        await db.rollback()
                        logger.error(f"Auto-sync error for user {account.user_id}: {user_err}")

        except Exception as loop_err:
            logger.error(f"Auto-sync loop error: {loop_err}")

        await asyncio.sleep(90)  # Run every 90 seconds

async def main():
    logger.info("Initializing Firebase...")
    init_firebase()

    logger.info("Starting Discord Bot...")
    from app.services.discord_bot import start_discord_bot
    discord_task = asyncio.create_task(start_discord_bot())

    # Run tasks concurrently
    await asyncio.gather(
        gmail_watch_renewal_loop(),
        auto_sync_loop(),
        discord_task,
        return_exceptions=True
    )

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Worker stopped by user.")
