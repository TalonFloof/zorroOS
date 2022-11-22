module logger

pub enum ZorroLogLevel {
	debug
	info
	warn
	error
	fatal
}

pub interface IZorroLogger {
	log(ZorroLogLevel,string)
}

pub fn (l IZorroLogger) debug(msg string) {
	l.log(ZorroLogLevel.debug,msg)
}

pub fn (l IZorroLogger) info(msg string) {
	l.log(ZorroLogLevel.info,msg)
}

pub fn (l IZorroLogger) warn(msg string) {
	l.log(ZorroLogLevel.warn,msg)
}

pub fn (l IZorroLogger) error(msg string) {
	l.log(ZorroLogLevel.error,msg)
}

pub fn (l IZorroLogger) fatal(msg string) {
	l.log(ZorroLogLevel.fatal,msg)
}