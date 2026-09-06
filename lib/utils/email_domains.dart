/// Email providers an account may be created with or changed to. Must stay
/// in sync with `ALLOWED_EMAIL_DOMAINS` in `csdo_api/db.php` — the backend
/// enforces the same list; this copy just gives a faster, friendlier error.
const allowedEmailDomains = {
  'gmail.com', 'googlemail.com',
  'yahoo.com', 'yahoo.com.ph', 'ymail.com', 'rocketmail.com',
  'outlook.com', 'outlook.ph', 'hotmail.com', 'live.com', 'msn.com',
  'hau.edu.ph',
};

/// The hint / helper text shown under an email field.
const allowedEmailProvidersHint = 'Gmail, Yahoo, or Outlook address';

/// The inline error shown when an email's domain isn't in the allowlist.
const allowedEmailProvidersError =
    'Please use a Gmail, Yahoo, or Outlook email address.';

bool isAllowedEmailProvider(String email) {
  final at = email.lastIndexOf('@');
  if (at == -1) return false;
  return allowedEmailDomains.contains(email.substring(at + 1).toLowerCase());
}
