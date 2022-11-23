module logger

import arch.interfaces.logger as i_log
import limine

[cinit]
__global (
	volatile terminal_request = limine.LimineTerminalRequest{response: 0}
)

pub struct Logger {}

pub fn (l &Logger) raw_log(msg string) {
	terminal_request.response.write(unsafe {terminal_request.response.terminals[0]},charptr(msg.str),u64(msg.len))
}

pub const (
	zorro_logger = i_log.IZorroLogger(Logger{})
)