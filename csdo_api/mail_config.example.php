<?php
/**
 * Copy this file to `mail_config.php` (same folder) and fill in the values.
 * `mail_config.php` is gitignored so real credentials never get committed.
 *
 * The backend sends two kinds of message: an email-verification code when an
 * account is created, and a password-reset code from "Forgot password?".
 * Both go out through the SMTP account configured here.
 *
 * --- Using a Holy Angel University (@hau.edu.ph) Microsoft 365 account ---
 * Microsoft 365 uses:
 *     SMTP_HOST = 'smtp.office365.com'
 *     SMTP_PORT = 587            (STARTTLS)
 *     SMTP_USER = 'youraccount@hau.edu.ph'
 *     SMTP_PASS = the account password, OR an App Password if the tenant
 *                 requires MFA (Security info -> App passwords in Office 365).
 *     MAIL_FROM = same @hau.edu.ph address (O365 rejects a From that isn't
 *                 the authenticated mailbox).
 *
 * NOTE: many school tenants disable "SMTP AUTH / authenticated client
 * submission" for security. If sending fails with 5.7.139 / "SmtpClient
 * Authentication is disabled", ask IT to enable SMTP AUTH for this one
 * mailbox, or keep MAIL_DEV_MODE on for the thesis demo (codes are written
 * to csdo_api/_mail_outbox/ and returned to the app in debug builds).
 */

const SMTP_HOST      = 'smtp.office365.com';
const SMTP_PORT      = 587;
const SMTP_USER      = '';                 // e.g. assetmanager@hau.edu.ph
const SMTP_PASS      = '';                 // account or app password
const MAIL_FROM      = '';                 // must equal SMTP_USER for O365
const MAIL_FROM_NAME = 'QREMS Asset Manager';

/**
 * When true: if SMTP isn't configured (blank SMTP_PASS) or a send fails, the
 * message is written to csdo_api/_mail_outbox/<timestamp>-<email>.txt instead
 * of the request erroring out, so the whole flow stays testable with no mail
 * server. Leave false for real delivery; flip to true only if you need to
 * work on the auth screens before SMTP is sorted out.
 */
const MAIL_DEV_MODE = false;

/**
 * When true (and only meaningful with MAIL_DEV_MODE on), the 6-digit code is
 * also included in the JSON API response as `dev_code`, so you can test
 * verification/reset without opening the outbox file. NEVER leave this on
 * outside local development.
 */
const MAIL_DEV_RETURN_CODE = false;
