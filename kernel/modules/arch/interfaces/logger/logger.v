module logger

pub enum ZorroLogLevel {
	debug
	info
	warn
	error
	fatal
}

pub interface IZorroLogger {
	raw_log(string)
}

pub fn (l &IZorroLogger) log(level ZorroLogLevel, msg string, newline bool) {
	match level {
		.debug {
			l.raw_log("\x1b[0;32m[DEBUG] | -> ")
			l.raw_log(msg)
			if newline {l.raw_log("\n")}
		}
		.info {
			l.raw_log("\x1b[0;36m[INFO] | -> ")
			l.raw_log(msg)
			if newline {l.raw_log("\n")}
		}
		.warn {
			l.raw_log("\x1b[0;33m[WARN] | -> ")
			l.raw_log(msg)
			if newline {l.raw_log("\n")}
		}
		.error {
			l.raw_log("\x1b[0;31m[ERROR] | -> ")
			l.raw_log(msg)
			if newline {l.raw_log("\n")}
		}
		.fatal {
			l.raw_log("\x1b[0;1;31m[FATAL] | -> ")
			l.raw_log(msg)
			if newline {l.raw_log("\n")}
		}
	}
}

pub fn (l &IZorroLogger) debug(msg string) {
	l.log(ZorroLogLevel.debug,msg,true)
}

pub fn (l &IZorroLogger) info(msg string) {
	l.log(ZorroLogLevel.info,msg,true)
}

pub fn (l &IZorroLogger) warn(msg string) {
	l.log(ZorroLogLevel.warn,msg,true)
}

pub fn (l &IZorroLogger) error(msg string) {
	l.log(ZorroLogLevel.error,msg,true)
}

pub fn (l &IZorroLogger) fatal(msg string) {
	l.log(ZorroLogLevel.fatal,msg,true)
}