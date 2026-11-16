use magnus::{function, prelude::*, Error, Ruby};

pub fn hello(subject: String) -> String {
    format!("Hello {subject}, from Rust!")
}

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    let module = ruby.define_module("Oxigraph")?;
    module.define_singleton_method("hello", function!(hello, 1))?;
    Ok(())
}
