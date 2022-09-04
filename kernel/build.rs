use std::env;

fn main() {
    /*match env::var("TARGET") {
		Ok(t) if t.ends_with("-vixenkernel") => (),
        Ok(t) => panic!("'{}' doesn't end with '-vixenkernel'", t),
        Err(env::VarError::NotPresent) => panic!("TARGET Environment Variable unset"),
        Err(env::VarError::NotUnicode(_)) => panic!("Target Triplet Inproperly Formatted")
	}*/
    println!("cargo:rerun-if-changed=build.rs");
}