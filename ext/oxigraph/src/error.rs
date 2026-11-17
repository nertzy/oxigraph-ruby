use std::fmt::Display;

use magnus::{kwargs, prelude::*, Error, ExceptionClass, RModule, Ruby};
use oxigraph::io::RdfSyntaxError;

/// Builds an `Oxigraph::Error`, the base class that `lib/oxigraph/errors.rb`
/// defines.
pub fn error(ruby: &Ruby, cause: impl Display) -> Error {
    named_error(ruby, "Error", cause)
}

/// Builds one of the subclasses of `Oxigraph::Error` that carry only a message.
pub fn named_error(ruby: &Ruby, class: &str, cause: impl Display) -> Error {
    match error_class(ruby, class) {
        Ok(class) => Error::new(class, cause.to_string()),
        Err(lookup_failure) => lookup_failure,
    }
}

/// Builds an `Oxigraph::ParseError` that carries where the input went wrong.
/// Upstream counts lines and columns from zero, and Ruby callers get them
/// counted from one, as upstream's own message does.
pub fn parse_error(ruby: &Ruby, cause: &RdfSyntaxError) -> Error {
    let start = cause.location().map(|location| location.start);
    let position = kwargs!(
        "line" => start.map(|start| start.line + 1),
        "column" => start.map(|start| start.column + 1)
    );
    let exception = error_class(ruby, "ParseError")
        .and_then(|class| class.new_instance((cause.to_string(), position)));
    match exception {
        Ok(exception) => exception.into(),
        Err(failure) => failure,
    }
}

pub fn argument_error(ruby: &Ruby, cause: impl Display) -> Error {
    Error::new(ruby.exception_arg_error(), cause.to_string())
}

fn error_class(ruby: &Ruby, name: &str) -> Result<ExceptionClass, Error> {
    ruby.class_object()
        .const_get::<_, RModule>("Oxigraph")?
        .const_get(name)
}
