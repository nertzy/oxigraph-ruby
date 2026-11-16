use magnus::{Error, Ruby};

mod error;
mod load;
mod model;
mod store;

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    let module = ruby.define_module("Oxigraph")?;
    model::init(ruby, module)?;
    store::init(ruby, module)
}
