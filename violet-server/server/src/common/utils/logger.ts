import { WinstonModule } from 'nest-winston';

const { format, transports } = require('winston');
const { combine, errors, timestamp, printf, json, splat, prettyPrint } = format;

require('winston-daily-rotate-file');

const myFormat = printf((x) => {
  const { level, message, label, timestamp, stack } = x;
  const log = `${timestamp} - ${level}: ${JSON.stringify(message, null, 2)}`;
  if (stack === undefined) {
    return log;
  } else {
    return `${log}\n${stack}`;
  }
});

const transport = new transports.DailyRotateFile({
  filename: './log/%DATE%.log',
  datePattern: 'YYYY-MM-DD',
});

export const logger = WinstonModule.createLogger({
  format: combine(
    errors({ stack: true }),
    timestamp(),
    json(),
    splat(),
    prettyPrint(),
    myFormat,
  ),
  transports: [transport],
});
