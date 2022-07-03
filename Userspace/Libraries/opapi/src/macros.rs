#[macro_export]
macro_rules! print {
    ($($arg:tt)*) => { 
        $crate::io::_print(format_args!($($arg)*))
     };
}

#[macro_export]
#[allow_internal_unstable(format_args_nl)]
macro_rules! println {
    () => {
        $crate::print!("\n")
    };
    ($($arg:tt)*) => { 
        $crate::io::_print(format_args_nl!($($arg)*))
    };
}