<?php
/**
 * Tiny dependency-free SMTP sender (STARTTLS + AUTH LOGIN), enough to send
 * plain-text mail through Microsoft 365 / Gmail / Mailtrap. No Composer or
 * PHPMailer needed, which keeps this runnable on a stock XAMPP install.
 *
 * Config comes from ../mail_config.php (see mail_config.example.php). If that
 * file is missing, or SMTP_PASS is blank, or a send fails while
 * MAIL_DEV_MODE is on, the message is dropped into ../_mail_outbox/ instead
 * so the sign-up / reset flows stay fully testable with no mail server.
 */

$__mailConfig = __DIR__ . '/../mail_config.php';
if (is_file($__mailConfig)) {
    require_once $__mailConfig;
}

// Fallbacks so the endpoints never fatal on a fresh checkout without a
// mail_config.php. With these defaults every send is "delivered" to the
// outbox folder.
if (!defined('SMTP_HOST')) define('SMTP_HOST', 'smtp.office365.com');
if (!defined('SMTP_PORT')) define('SMTP_PORT', 587);
if (!defined('SMTP_USER')) define('SMTP_USER', '');
if (!defined('SMTP_PASS')) define('SMTP_PASS', '');
if (!defined('MAIL_FROM')) define('MAIL_FROM', SMTP_USER);
if (!defined('MAIL_FROM_NAME')) define('MAIL_FROM_NAME', 'QREMS Asset Manager');
if (!defined('MAIL_DEV_MODE')) define('MAIL_DEV_MODE', false);
if (!defined('MAIL_DEV_RETURN_CODE')) define('MAIL_DEV_RETURN_CODE', false);

/** True when real SMTP delivery is configured. */
function mailer_is_live(): bool {
    return SMTP_PASS !== '' && SMTP_USER !== '';
}

/**
 * Sends a plain-text email. Returns a short status string:
 *   'sent'   - handed off to the SMTP server
 *   'outbox' - written to _mail_outbox/ (dev mode, no/broken SMTP)
 * Throws RuntimeException only when delivery fails AND dev mode is off.
 */
function send_mail(string $to, string $subject, string $body): string {
    if (!mailer_is_live()) {
        if (MAIL_DEV_MODE) {
            return _mail_to_outbox($to, $subject, $body, 'SMTP not configured');
        }
        throw new RuntimeException('Mail is not configured on the server.');
    }

    try {
        _smtp_send($to, $subject, $body);
        return 'sent';
    } catch (Throwable $e) {
        if (MAIL_DEV_MODE) {
            return _mail_to_outbox($to, $subject, $body, 'SMTP error: ' . $e->getMessage());
        }
        throw new RuntimeException('Could not send the email: ' . $e->getMessage());
    }
}

/** Writes the message to ../_mail_outbox/ and returns 'outbox'. */
function _mail_to_outbox(string $to, string $subject, string $body, string $reason): string {
    $dir = __DIR__ . '/../_mail_outbox';
    if (!is_dir($dir)) {
        @mkdir($dir, 0777, true);
    }
    $safe = preg_replace('/[^a-zA-Z0-9._@-]/', '_', $to);
    $file = $dir . '/' . date('Ymd-His') . '-' . $safe . '.txt';
    $contents = "To: $to\nFrom: " . MAIL_FROM . "\nSubject: $subject\n"
        . "X-Dev-Reason: $reason\nDate: " . date('r') . "\n\n" . $body . "\n";
    @file_put_contents($file, $contents);
    return 'outbox';
}

/**
 * Minimal SMTP conversation: connect, EHLO, STARTTLS, EHLO, AUTH LOGIN,
 * MAIL FROM / RCPT TO / DATA. Plain-text body only.
 */
function _smtp_send(string $to, string $subject, string $body): void {
    $host = SMTP_HOST;
    $port = (int) SMTP_PORT;

    $fp = @stream_socket_client(
        "tcp://$host:$port",
        $errno,
        $errstr,
        20,
        STREAM_CLIENT_CONNECT
    );
    if (!$fp) {
        throw new RuntimeException("connect failed ($errno): $errstr");
    }
    stream_set_timeout($fp, 20);

    $read = function () use ($fp): string {
        $data = '';
        while (($line = fgets($fp, 515)) !== false) {
            $data .= $line;
            // A multiline reply has a '-' after the code; the last line has a space.
            if (isset($line[3]) && $line[3] === ' ') break;
        }
        return $data;
    };
    $expect = function (string $resp, string $codes, string $stage) {
        $code = substr($resp, 0, 3);
        if (strpos($codes, $code) === false) {
            throw new RuntimeException("$stage: unexpected reply " . trim($resp));
        }
    };
    $cmd = function (string $line) use ($fp): void {
        fwrite($fp, $line . "\r\n");
    };

    $host_ehlo = 'localhost';

    $expect($read(), '220', 'greeting');

    $cmd("EHLO $host_ehlo");
    $expect($read(), '250', 'EHLO');

    $cmd('STARTTLS');
    $expect($read(), '220', 'STARTTLS');

    $crypto = STREAM_CRYPTO_METHOD_TLS_CLIENT;
    if (defined('STREAM_CRYPTO_METHOD_TLSv1_2_CLIENT')) {
        $crypto |= STREAM_CRYPTO_METHOD_TLSv1_2_CLIENT;
    }
    if (defined('STREAM_CRYPTO_METHOD_TLSv1_3_CLIENT')) {
        $crypto |= STREAM_CRYPTO_METHOD_TLSv1_3_CLIENT;
    }
    if (!stream_socket_enable_crypto($fp, true, $crypto)) {
        throw new RuntimeException('TLS negotiation failed');
    }

    $cmd("EHLO $host_ehlo");
    $expect($read(), '250', 'EHLO(tls)');

    $cmd('AUTH LOGIN');
    $expect($read(), '334', 'AUTH LOGIN');
    $cmd(base64_encode(SMTP_USER));
    $expect($read(), '334', 'AUTH user');
    $cmd(base64_encode(SMTP_PASS));
    $expect($read(), '235', 'AUTH pass');

    $from = MAIL_FROM !== '' ? MAIL_FROM : SMTP_USER;
    $cmd("MAIL FROM:<$from>");
    $expect($read(), '250', 'MAIL FROM');
    $cmd("RCPT TO:<$to>");
    $expect($read(), '250 251', 'RCPT TO');
    $cmd('DATA');
    $expect($read(), '354', 'DATA');

    $headers = "From: " . MAIL_FROM_NAME . " <$from>\r\n"
        . "To: <$to>\r\n"
        . "Subject: " . _encode_header($subject) . "\r\n"
        . "MIME-Version: 1.0\r\n"
        . "Content-Type: text/plain; charset=UTF-8\r\n"
        . "Content-Transfer-Encoding: 8bit\r\n"
        . "Date: " . date('r') . "\r\n";

    // Dot-stuffing: a line that is just "." would end DATA early.
    $normalisedBody = preg_replace('/\r\n?|\n/', "\r\n", $body);
    $normalisedBody = preg_replace('/^\./m', '..', $normalisedBody);

    fwrite($fp, $headers . "\r\n" . $normalisedBody . "\r\n.\r\n");
    $expect($read(), '250', 'end of DATA');

    $cmd('QUIT');
    fclose($fp);
}

/** RFC 2047 encodes a header value only if it has non-ASCII characters. */
function _encode_header(string $value): string {
    if (preg_match('/[^\x20-\x7E]/', $value)) {
        return '=?UTF-8?B?' . base64_encode($value) . '?=';
    }
    return $value;
}
