export const PASSWORD_RECOVERY_CALLBACK_PATH = "/auth/callback";
export const PASSWORD_RECOVERY_PATH = "/reset-password";
export const PASSWORD_RECOVERY_COOKIE = "artisan-lane-password-recovery";
export const PASSWORD_RECOVERY_COOKIE_MAX_AGE = 15 * 60;
export const PASSWORD_MIN_LENGTH = 8;

export function getPasswordRecoveryRedirectUrl(origin: string) {
  return new URL(PASSWORD_RECOVERY_CALLBACK_PATH, origin).toString();
}

export function validateRecoveryPassword(
  password: string,
  confirmation: string,
) {
  if (password.length < PASSWORD_MIN_LENGTH) {
    return `Use at least ${PASSWORD_MIN_LENGTH} characters for your new password.`;
  }

  if (password !== confirmation) {
    return "The passwords do not match.";
  }

  return null;
}
