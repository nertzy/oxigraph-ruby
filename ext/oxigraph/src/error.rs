use std::fmt::Display;

use magnus::{kwargs, prelude::*, Error, ExceptionClass, RModule, Ruby};
use oxigraph::io::RdfSyntaxError;
use spargebra::SparqlSyntaxError;

use crate::prefix::first_undeclared;

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

/// Builds an `Oxigraph::QuerySyntaxError` that carries where a query or update
/// went wrong. Upstream keeps the position private and begins its message with
/// it, so it is read back from there. An error upstream reports without a
/// position leaves both nil.
///
/// `text` is what upstream refused and `declared` the prefixes the caller
/// passed. When the text uses a prefix nothing declared, the error names it
/// and points at it. The parser stops just after such a name, so a name
/// beyond where it stopped is not what it refused, and its own message stays.
pub fn query_syntax_error(
    ruby: &Ruby,
    cause: &SparqlSyntaxError,
    text: &str,
    declared: &[String],
) -> Error {
    let mut message = cause.to_string();
    let mut start = position_in(&message);
    if let (Some(reached), Some(name)) = (start, first_undeclared(text, declared)) {
        if (name.line, name.column) < reached {
            message = format!(
                "error at {}:{}: the prefix \"{}:\" is not declared",
                name.line, name.column, name.prefix
            );
            start = Some((name.line, name.column));
        }
    }
    let position = kwargs!(
        "line" => start.map(|(line, _)| line),
        "column" => start.map(|(_, column)| column)
    );
    let exception = error_class(ruby, "QuerySyntaxError")
        .and_then(|class| class.new_instance((message, position)));
    match exception {
        Ok(exception) => exception.into(),
        Err(failure) => failure,
    }
}

/// Reads the line and column from a message such as
/// `error at 3:9: expected ...`, both already counted from one.
fn position_in(message: &str) -> Option<(usize, usize)> {
    let (position, _) = message.strip_prefix("error at ")?.split_once(": ")?;
    let (line, column) = position.split_once(':')?;
    Some((line.parse().ok()?, column.parse().ok()?))
}

pub fn argument_error(ruby: &Ruby, cause: impl Display) -> Error {
    Error::new(ruby.exception_arg_error(), cause.to_string())
}

fn error_class(ruby: &Ruby, name: &str) -> Result<ExceptionClass, Error> {
    ruby.class_object()
        .const_get::<_, RModule>("Oxigraph")?
        .const_get(name)
}
