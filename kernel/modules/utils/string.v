module utils

pub fn reverse(mut str &u8, length usize) {
    mut end := &u8(usize(str)+length-1)
    for i := 0; i < length / 2; i++ {
        c := *end
        unsafe {
            *end = *str
            *str = c
        }
        unsafe {(str)++}
        unsafe {end--}
    }
}

pub fn itoa(num_ u64, mut str &u8, base int) string {
	mut i := int(0)
	mut num := num_
	if num == 0 {
		str[i] = `0`
		i++
		str[i] = `\0`
		return unsafe {tos2(str)}
	}
	for num != 0 {
		rem := num % u64(base)
		str[i] = u8(if rem > 9 {(rem - 10) + `a`} else {rem + `0`})
		i++
		num = num / u64(base)
	}
	str[i] = `\0`
    reverse(mut str,usize(i))
	return unsafe {tos2(str)}
}