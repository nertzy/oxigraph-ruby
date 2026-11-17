use magnus::{Error, Ruby};

mod error;
mod store;

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    let module = ruby.define_module("Oxigraph")?;
    store::init(ruby, module)
}
