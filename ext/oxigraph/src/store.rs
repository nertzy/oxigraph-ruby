use magnus::{function, method, prelude::*, Error, RModule, Ruby};

use crate::error::error;

/// An RDF dataset held in memory, exposed to Ruby as `Oxigraph::Store`.
#[magnus::wrap(class = "Oxigraph::Store", free_immediately, size)]
pub struct Store {
    inner: oxigraph::store::Store,
}

impl Store {
    fn new(ruby: &Ruby) -> Result<Self, Error> {
        let inner = oxigraph::store::Store::new().map_err(|cause| error(ruby, cause))?;
        Ok(Self { inner })
    }

    fn size(ruby: &Ruby, rb_self: &Self) -> Result<usize, Error> {
        rb_self.inner.len().map_err(|cause| error(ruby, cause))
    }

    fn is_empty(ruby: &Ruby, rb_self: &Self) -> Result<bool, Error> {
        rb_self.inner.is_empty().map_err(|cause| error(ruby, cause))
    }
}

pub fn init(ruby: &Ruby, module: RModule) -> Result<(), Error> {
    let class = module.define_class("Store", ruby.class_object())?;
    class.define_singleton_method("new", function!(Store::new, 0))?;
    class.define_method("size", method!(Store::size, 0))?;
    class.define_method("empty?", method!(Store::is_empty, 0))?;
    Ok(())
}
