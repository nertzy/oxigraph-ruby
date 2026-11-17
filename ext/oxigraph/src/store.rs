use magnus::{function, method, prelude::*, Error, RModule, Ruby, Symbol, Value};

use crate::error::error;
use crate::load::load;
use crate::query::evaluate;

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

    fn query(ruby: &Ruby, rb_self: &Self, query: Value) -> Result<Value, Error> {
        evaluate(ruby, &rb_self.inner, query)
    }

    /// The private half of `Store#load`, which `lib/oxigraph/store.rb` calls
    /// once it has settled where the input comes from.
    fn load_input(
        ruby: &Ruby,
        rb_self: &Self,
        input: Value,
        format: Option<Symbol>,
        extension: Option<String>,
        base_iri: Option<String>,
    ) -> Result<Value, Error> {
        load(ruby, &rb_self.inner, input, format, extension, base_iri)
    }
}

pub fn init(ruby: &Ruby, module: RModule) -> Result<(), Error> {
    let class = module.define_class("Store", ruby.class_object())?;
    class.undef_default_alloc_func();
    class.define_singleton_method("new", function!(Store::new, 0))?;
    class.define_method("size", method!(Store::size, 0))?;
    class.define_method("empty?", method!(Store::is_empty, 0))?;
    class.define_method("query", method!(Store::query, 1))?;
    class.define_private_method("load_input", method!(Store::load_input, 4))?;
    Ok(())
}
