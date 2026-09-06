<?php
/**
 * Issue + verify short-lived 6-digit codes for email verification and
 * password reset. Backed by the `auth_codes` table (see schema.sql).
 *
 * Design:
 * - A code is 6 numeric digits, valid for AUTH_CODE_TTL_MIN minutes.
 * - Only the hash is stored, never the raw code.
 * - Issuing a new code for an (email, purpose) pair invalidates any earlier
 *   unconsumed codes for that pair.
 * - At most AUTH_CODE_MAX_PER_HOUR codes may be issued per (email, purpose)
 *   per hour.
 * - A code allows at most AUTH_CODE_MAX_ATTEMPTS wrong guesses before it is
 *   burned.
 */

const AUTH_CODE_TTL_MIN        = 15;
const AUTH_CODE_MAX_PER_HOUR   = 5;
const AUTH_CODE_MAX_ATTEMPTS   = 5;

const AUTH_PURPOSE_VERIFY = 'verify';
const AUTH_PURPOSE_RESET  = 'reset';

/**
 * Creates and stores a fresh code for ($email, $purpose) and returns the raw
 * 6-digit string (the caller emails it). Throws RuntimeException with a
 * user-safe message if the hourly limit is hit.
 */
function issue_auth_code(mysqli $mysqli, string $email, string $purpose): string {
    $email = strtolower(trim($email));

    // Hourly rate limit.
    $stmt = $mysqli->prepare(
        'SELECT COUNT(*) AS n FROM auth_codes ' .
        'WHERE email = ? AND purpose = ? AND created_at > (NOW() - INTERVAL 1 HOUR)'
    );
    $stmt->bind_param('ss', $email, $purpose);
    $stmt->execute();
    $recent = (int) ($stmt->get_result()->fetch_assoc()['n'] ?? 0);
    $stmt->close();
    if ($recent >= AUTH_CODE_MAX_PER_HOUR) {
        throw new RuntimeException(
            'Too many codes requested for this email. Please wait a while and try again.'
        );
    }

    // Invalidate earlier unconsumed codes for this pair.
    $stmt = $mysqli->prepare(
        'UPDATE auth_codes SET consumed_at = NOW() ' .
        'WHERE email = ? AND purpose = ? AND consumed_at IS NULL'
    );
    $stmt->bind_param('ss', $email, $purpose);
    $stmt->execute();
    $stmt->close();

    $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
    $hash = password_hash($code, PASSWORD_DEFAULT);

    $stmt = $mysqli->prepare(
        'INSERT INTO auth_codes (email, code_hash, purpose, expires_at) ' .
        'VALUES (?, ?, ?, (NOW() + INTERVAL ? MINUTE))'
    );
    $ttl = AUTH_CODE_TTL_MIN;
    $stmt->bind_param('sssi', $email, $hash, $purpose, $ttl);
    if (!$stmt->execute()) {
        $stmt->close();
        throw new RuntimeException('Could not create a verification code.');
    }
    $stmt->close();

    return $code;
}

/**
 * Checks $code against the newest live code for ($email, $purpose).
 * On success the code is consumed and true is returned. On failure the
 * attempt counter is bumped (and the code burned once it is exhausted) and
 * false is returned.
 */
function verify_auth_code(mysqli $mysqli, string $email, string $purpose, string $code): bool {
    $email = strtolower(trim($email));
    $code = trim($code);

    $stmt = $mysqli->prepare(
        'SELECT id, code_hash, attempts FROM auth_codes ' .
        'WHERE email = ? AND purpose = ? AND consumed_at IS NULL AND expires_at > NOW() ' .
        'ORDER BY id DESC LIMIT 1'
    );
    $stmt->bind_param('ss', $email, $purpose);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$row) {
        return false;
    }

    if ((int) $row['attempts'] >= AUTH_CODE_MAX_ATTEMPTS) {
        // Burn it so a fresh code must be requested.
        $burn = $mysqli->prepare('UPDATE auth_codes SET consumed_at = NOW() WHERE id = ?');
        $burn->bind_param('i', $row['id']);
        $burn->execute();
        $burn->close();
        return false;
    }

    if (!password_verify($code, $row['code_hash'])) {
        $bump = $mysqli->prepare('UPDATE auth_codes SET attempts = attempts + 1 WHERE id = ?');
        $bump->bind_param('i', $row['id']);
        $bump->execute();
        $bump->close();
        return false;
    }

    $done = $mysqli->prepare('UPDATE auth_codes SET consumed_at = NOW() WHERE id = ?');
    $done->bind_param('i', $row['id']);
    $done->execute();
    $done->close();
    return true;
}

/** Body text for a verification email. */
function verify_email_body(string $code): string {
    return "Welcome to QREMS Asset Manager.\n\n"
        . "Your email verification code is: $code\n\n"
        . "Enter this code in the app to activate your account. "
        . "It expires in " . AUTH_CODE_TTL_MIN . " minutes.\n\n"
        . "If you did not create an account, you can ignore this email.";
}

/** Body text for a password-reset email. */
function reset_email_body(string $code): string {
    return "A password reset was requested for your QREMS Asset Manager account.\n\n"
        . "Your reset code is: $code\n\n"
        . "Enter this code in the app to set a new password. "
        . "It expires in " . AUTH_CODE_TTL_MIN . " minutes.\n\n"
        . "If you did not request this, you can ignore this email; your password will not change.";
}
