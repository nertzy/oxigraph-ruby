use std::io::{self, BufReader, Read};

use magnus::{prelude::*, Error, RModule, RString, Ruby, Symbol, Value};
use oxigraph::io::{JsonLdProfileSet, RdfFormat, RdfParseError, RdfParser};
use oxigraph::store::Store;

use crate::error::{argument_error, error, parse_error};

/// The most that is asked of a Ruby reader in one call.
const CHUNK_SIZE: usize = 64 * 1024;

/// Loads RDF into `store` from a Ruby `String` of content or from an object
/// that responds to `read`, and returns an `Oxigraph::LoadSummary`.
pub fn load(
    ruby: &Ruby,
    store: &Store,
    input: Value,
    format: Option<Symbol>,
    extension: Option<String>,
    base_iri: Option<String>,
) -> Result<Value, Error> {
    let mut parser = RdfParser::from_format(format_from(ruby, format, extension)?);
    if let Some(base_iri) = base_iri {
        parser = parser
            .with_base_iri(base_iri)
            .map_err(|cause| argument_error(ruby, cause))?;
    }

    let loaded = if let Some(content) = RString::from_value(input) {
        // Copied so that the parser never borrows memory that Ruby owns.
        let content = unsafe { content.as_slice() }.to_vec();
        load_quads(ruby, store, parser, content.as_slice())?
    } else if input.respond_to("read", false)? {
        let mut raised = None;
        let outcome = {
            let reader = RubyReader {
                reader: input,
                raised: &mut raised,
            };
            let reader = BufReader::with_capacity(CHUNK_SIZE, reader);
            load_quads(ruby, store, parser, reader)
        };
        // What the reader raised is the cause, so it wins over the parser's
        // report of a failed read.
        match raised {
            Some(raised) => return Err(raised),
            None => outcome?,
        }
    } else {
        return Err(Error::new(
            ruby.exception_type_error(),
            format!(
                "wrong argument type {} (expected a String or an object that responds to read)",
                input.class()
            ),
        ));
    };

    let prefixes = ruby.hash_new();
    for (name, iri) in loaded.prefixes {
        prefixes.aset(name, iri)?;
    }
    prefixes.freeze();
    ruby.class_object()
        .const_get::<_, RModule>("Oxigraph")?
        .const_get::<_, Value>("LoadSummary")?
        .funcall("new", (prefixes, loaded.base_iri))
}

/// What the parser knew when it reached the end of the input.
struct Loaded {
    prefixes: Vec<(String, String)>,
    base_iri: Option<String>,
}

/// Parses `reader` into one transaction, so a failure part-way through leaves
/// the store as it was.
fn load_quads(
    ruby: &Ruby,
    store: &Store,
    parser: RdfParser,
    reader: impl Read,
) -> Result<Loaded, Error> {
    let mut transaction = store
        .start_transaction()
        .map_err(|cause| error(ruby, cause))?;
    let mut quads = parser.rename_blank_nodes().for_reader(reader);
    for quad in &mut quads {
        match quad {
            Ok(quad) => transaction.insert(quad.as_ref()),
            Err(RdfParseError::Syntax(cause)) => return Err(parse_error(ruby, &cause)),
            Err(RdfParseError::Io(cause)) => return Err(error(ruby, cause)),
        }
    }
    let loaded = Loaded {
        prefixes: quads
            .prefixes()
            .map(|(name, iri)| (name.to_owned(), iri.to_owned()))
            .collect(),
        base_iri: quads.base_iri().map(str::to_owned),
    };
    transaction.commit().map_err(|cause| error(ruby, cause))?;
    Ok(loaded)
}

fn format_from(
    ruby: &Ruby,
    format: Option<Symbol>,
    extension: Option<String>,
) -> Result<RdfFormat, Error> {
    let Some(format) = format else {
        return match extension {
            Some(extension) => RdfFormat::from_extension(extension.trim_start_matches('.'))
                .ok_or_else(|| {
                    let file = if extension.is_empty() {
                        "a file with no extension".to_owned()
                    } else {
                        format!("a {extension} file")
                    };
                    argument_error(
                        ruby,
                        format!("cannot tell the RDF format of {file}; pass format:"),
                    )
                }),
            None => Err(argument_error(
                ruby,
                "format: is required when loading from a string or a reader",
            )),
        };
    };
    match &*format.name()? {
        "turtle" => Ok(RdfFormat::Turtle),
        "rdf_xml" => Ok(RdfFormat::RdfXml),
        "n_triples" => Ok(RdfFormat::NTriples),
        "n_quads" => Ok(RdfFormat::NQuads),
        "trig" => Ok(RdfFormat::TriG),
        "n3" => Ok(RdfFormat::N3),
        "json_ld" => Ok(RdfFormat::JsonLd {
            profile: JsonLdProfileSet::empty(),
        }),
        unknown => Err(argument_error(
            ruby,
            format!(
                "unknown format :{unknown}; expected :turtle, :rdf_xml, :n_triples, :n_quads, :trig, :n3, or :json_ld"
            ),
        )),
    }
}

/// Reads from a Ruby object by calling its `read(length)`, as `IO` defines it:
/// a `String` of at most `length` bytes, or `nil` at the end.
struct RubyReader<'a> {
    reader: Value,
    raised: &'a mut Option<Error>,
}

impl Read for RubyReader<'_> {
    fn read(&mut self, buffer: &mut [u8]) -> io::Result<usize> {
        let chunk = self
            .reader
            .funcall::<_, _, Option<RString>>("read", (buffer.len(),));
        match chunk {
            Ok(None) => Ok(0),
            Ok(Some(chunk)) => {
                // Copied out before any other Ruby code can run.
                let bytes = unsafe { chunk.as_slice() };
                let Some(target) = buffer.get_mut(..bytes.len()) else {
                    return Err(io::Error::other(
                        "the reader returned more bytes than were asked for",
                    ));
                };
                target.copy_from_slice(bytes);
                Ok(bytes.len())
            }
            Err(raised) => {
                *self.raised = Some(raised);
                Err(io::Error::other("the reader raised an exception"))
            }
        }
    }
}
