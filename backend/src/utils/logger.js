/**
 * Simple logger utility for better error tracking
 * Can be extended with Winston or other logging libraries later
 */

const LOG_LEVELS = {
  ERROR: 'ERROR',
  WARN: 'WARN',
  INFO: 'INFO',
  DEBUG: 'DEBUG',
};

function formatLog(level, message, data = null) {
  const timestamp = new Date().toISOString();
  const logEntry = {
    timestamp,
    level,
    message,
    ...(data && { data }),
  };
  return JSON.stringify(logEntry);
}

export const logger = {
  error(message, error = null) {
    const errorData = error ? {
      message: error.message,
      stack: error.stack?.substring(0, 500),
      code: error.code,
    } : null;
    console.error(formatLog(LOG_LEVELS.ERROR, message, errorData));
  },

  warn(message, data = null) {
    console.warn(formatLog(LOG_LEVELS.WARN, message, data));
  },

  info(message, data = null) {
    console.log(formatLog(LOG_LEVELS.INFO, message, data));
  },

  debug(message, data = null) {
    if (process.env.NODE_ENV === 'development') {
      console.log(formatLog(LOG_LEVELS.DEBUG, message, data));
    }
  },
};

