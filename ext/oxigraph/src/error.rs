use std::fmt::Display;

use magnus::{prelude::*, Error, ExceptionClass, RModule, Ruby};

/// Builds an `Oxigraph::Error`, the base class that `lib/oxigraph.rb` defines.
pub fn error(ruby: &Ruby, cause: impl Display) -> Error {
    let class = ruby
        .class_object()
        .const_get::<_, RModule>("Oxigraph")
        .and_then(|module| module.const_get::<_, ExceptionClass>("Error"));
    match class {
        Ok(class) => Error::new(class, cause.to_string()),
        Err(lookup_failure) => lookup_failure,
    }
}
