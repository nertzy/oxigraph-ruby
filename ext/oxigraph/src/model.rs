use std::fmt::Display;
use std::hash::{BuildHasher, Hash, RandomState};
use std::sync::OnceLock;

use magnus::{
    function, method, prelude::*, scan_args, typed_data::Obj, Error, RClass, RHash, RModule, Ruby,
    TryConvert, TypedData, Value,
};
use oxigraph::model as rdf;

use crate::error::argument_error;

/// An IRI, exposed to Ruby as `Oxigraph::NamedNode`.
#[derive(PartialEq, Eq, Hash)]
#[magnus::wrap(class = "Oxigraph::NamedNode", free_immediately, size)]
pub struct NamedNode {
    inner: rdf::NamedNode,
}

impl NamedNode {
    fn new(ruby: &Ruby, iri: String) -> Result<Obj<Self>, Error> {
        let inner = rdf::NamedNode::new(iri).map_err(|cause| argument_error(ruby, cause))?;
        Ok(frozen(ruby, Self { inner }))
    }

    fn value(&self) -> String {
        self.inner.as_str().to_owned()
    }

    fn to_s(&self) -> String {
        self.inner.to_string()
    }

    fn inspect(&self) -> String {
        inspect("NamedNode", &self.inner)
    }

    fn equals(&self, other: Value) -> bool {
        equals(self, other)
    }

    fn hash(&self) -> u64 {
        hash(self)
    }
}

/// A blank node, exposed to Ruby as `Oxigraph::BlankNode`.
#[derive(PartialEq, Eq, Hash)]
#[magnus::wrap(class = "Oxigraph::BlankNode", free_immediately, size)]
pub struct BlankNode {
    inner: rdf::BlankNode,
}

impl BlankNode {
    fn new(ruby: &Ruby, args: &[Value]) -> Result<Obj<Self>, Error> {
        let args = scan_args::scan_args::<(), (Option<String>,), (), (), (), ()>(args)?;
        let inner = match args.optional.0 {
            Some(id) => rdf::BlankNode::new(id).map_err(|cause| argument_error(ruby, cause))?,
            None => rdf::BlankNode::default(),
        };
        Ok(frozen(ruby, Self { inner }))
    }

    fn value(&self) -> String {
        self.inner.as_str().to_owned()
    }

    fn to_s(&self) -> String {
        self.inner.to_string()
    }

    fn inspect(&self) -> String {
        inspect("BlankNode", &self.inner)
    }

    fn equals(&self, other: Value) -> bool {
        equals(self, other)
    }

    fn hash(&self) -> u64 {
        hash(self)
    }
}

/// A literal, exposed to Ruby as `Oxigraph::Literal`.
#[derive(PartialEq, Eq, Hash)]
#[magnus::wrap(class = "Oxigraph::Literal", free_immediately, size)]
pub struct Literal {
    inner: rdf::Literal,
}

impl Literal {
    fn new(ruby: &Ruby, args: &[Value]) -> Result<Obj<Self>, Error> {
        let args = scan_args::scan_args::<(String,), (), (), (), RHash, ()>(args)?;
        let keywords = scan_args::get_kwargs::<
            _,
            (),
            (Option<Option<Value>>, Option<Option<String>>),
            (),
        >(args.keywords, &[], &["datatype", "language"])?;
        let (value,) = args.required;
        let (datatype, language) = keywords.optional;
        let inner = match (datatype.flatten(), language.flatten()) {
            (Some(_), Some(_)) => {
                return Err(argument_error(
                    ruby,
                    "a literal takes a datatype or a language, not both",
                ))
            }
            (Some(datatype), None) => {
                let datatype = <&NamedNode>::try_convert(datatype)?;
                rdf::Literal::new_typed_literal(value, datatype.inner.clone())
            }
            (None, Some(language)) => rdf::Literal::new_language_tagged_literal(value, language)
                .map_err(|cause| argument_error(ruby, cause))?,
            (None, None) => rdf::Literal::new_simple_literal(value),
        };
        Ok(frozen(ruby, Self { inner }))
    }

    fn value(&self) -> String {
        self.inner.value().to_owned()
    }

    fn datatype(ruby: &Ruby, rb_self: &Self) -> Obj<NamedNode> {
        let inner = rb_self.inner.datatype().into_owned();
        frozen(ruby, NamedNode { inner })
    }

    fn language(&self) -> Option<String> {
        self.inner.language().map(str::to_owned)
    }

    fn to_s(&self) -> String {
        self.inner.to_string()
    }

    fn inspect(&self) -> String {
        inspect("Literal", &self.inner)
    }

    fn equals(&self, other: Value) -> bool {
        equals(self, other)
    }

    fn hash(&self) -> u64 {
        hash(self)
    }
}

/// A subject, predicate, and object, exposed to Ruby as `Oxigraph::Triple`.
#[derive(PartialEq, Eq, Hash)]
#[magnus::wrap(class = "Oxigraph::Triple", free_immediately, size)]
pub struct Triple {
    inner: rdf::Triple,
}

impl Triple {
    fn new(
        ruby: &Ruby,
        subject: Value,
        predicate: Value,
        object: Value,
    ) -> Result<Obj<Self>, Error> {
        let inner = rdf::Triple::new(
            subject_from(ruby, subject)?,
            <&NamedNode>::try_convert(predicate)?.inner.clone(),
            term_from(ruby, object)?,
        );
        Ok(frozen(ruby, Self { inner }))
    }

    fn subject(ruby: &Ruby, rb_self: &Self) -> Value {
        match rb_self.inner.subject.clone() {
            rdf::NamedOrBlankNode::NamedNode(inner) => frozen(ruby, NamedNode { inner }).as_value(),
            rdf::NamedOrBlankNode::BlankNode(inner) => frozen(ruby, BlankNode { inner }).as_value(),
        }
    }

    fn predicate(ruby: &Ruby, rb_self: &Self) -> Obj<NamedNode> {
        let inner = rb_self.inner.predicate.clone();
        frozen(ruby, NamedNode { inner })
    }

    fn object(ruby: &Ruby, rb_self: &Self) -> Value {
        term_to_value(ruby, rb_self.inner.object.clone())
    }

    fn to_s(&self) -> String {
        self.inner.to_string()
    }

    fn inspect(&self) -> String {
        inspect("Triple", &self.inner)
    }

    fn equals(&self, other: Value) -> bool {
        equals(self, other)
    }

    fn hash(&self) -> u64 {
        hash(self)
    }
}

/// Wraps a term from a query result in the Ruby class for its kind.
pub fn term_to_value(ruby: &Ruby, term: rdf::Term) -> Value {
    match term {
        rdf::Term::NamedNode(inner) => frozen(ruby, NamedNode { inner }).as_value(),
        rdf::Term::BlankNode(inner) => frozen(ruby, BlankNode { inner }).as_value(),
        rdf::Term::Literal(inner) => frozen(ruby, Literal { inner }).as_value(),
    }
}

/// Wraps a triple from a query result as an `Oxigraph::Triple`.
pub fn triple_to_value(ruby: &Ruby, inner: rdf::Triple) -> Value {
    frozen(ruby, Triple { inner }).as_value()
}

/// Wraps a term for Ruby and freezes it: terms have no mutating methods, and a
/// frozen object says so.
pub fn frozen<T: TypedData>(ruby: &Ruby, term: T) -> Obj<T> {
    let object = ruby.obj_wrap(term);
    object.freeze();
    object
}

/// Copying a term returns the term itself, because terms are frozen values.
/// Without these methods `dup` and `clone` raise, because the class has no
/// allocator. They take the arguments that copying an `Integer` takes.
fn dup(term: Value) -> Value {
    term
}

fn clone(ruby: &Ruby, term: Value, arguments: &[Value]) -> Result<Value, Error> {
    let arguments = scan_args::scan_args::<(), (), (), (), RHash, ()>(arguments)?;
    let keywords =
        scan_args::get_kwargs::<_, (), (Option<Value>,), ()>(arguments.keywords, &[], &["freeze"])?;
    match keywords.optional.0 {
        Some(freeze) if freeze.is_kind_of(ruby.class_false_class()) => Err(argument_error(
            ruby,
            format!("can't unfreeze {}", term.class()),
        )),
        Some(freeze) if !freeze.is_nil() && !freeze.is_kind_of(ruby.class_true_class()) => {
            Err(argument_error(
                ruby,
                format!("unexpected value for freeze: {}", freeze.class()),
            ))
        }
        _ => Ok(term),
    }
}

fn define_copying(class: RClass) -> Result<(), Error> {
    class.define_method("dup", method!(dup, 0))?;
    class.define_method("clone", method!(clone, -1))
}

fn inspect(class: &str, term: &impl Display) -> String {
    format!("#<Oxigraph::{class} {term}>")
}

/// A term equals another object only when that object is the same kind of term
/// with the same content.
fn equals<T: TypedData + PartialEq>(term: &T, other: Value) -> bool {
    <&T>::try_convert(other).is_ok_and(|other| term == other)
}

/// Hashes with keys chosen once per process, as Ruby does for strings, so that
/// terms built from untrusted input cannot be made to collide as `Hash` keys.
/// The result is kept within Ruby's small-integer range.
fn hash(term: &impl Hash) -> u64 {
    static KEYS: OnceLock<RandomState> = OnceLock::new();
    KEYS.get_or_init(RandomState::new).hash_one(term) >> 2
}

fn subject_from(ruby: &Ruby, value: Value) -> Result<rdf::NamedOrBlankNode, Error> {
    if let Ok(node) = <&NamedNode>::try_convert(value) {
        Ok(node.inner.clone().into())
    } else if let Ok(node) = <&BlankNode>::try_convert(value) {
        Ok(node.inner.clone().into())
    } else {
        Err(type_error(
            ruby,
            value,
            "Oxigraph::NamedNode or Oxigraph::BlankNode",
        ))
    }
}

fn term_from(ruby: &Ruby, value: Value) -> Result<rdf::Term, Error> {
    if let Ok(node) = <&NamedNode>::try_convert(value) {
        Ok(node.inner.clone().into())
    } else if let Ok(node) = <&BlankNode>::try_convert(value) {
        Ok(node.inner.clone().into())
    } else if let Ok(literal) = <&Literal>::try_convert(value) {
        Ok(literal.inner.clone().into())
    } else {
        Err(type_error(
            ruby,
            value,
            "Oxigraph::NamedNode, Oxigraph::BlankNode, or Oxigraph::Literal",
        ))
    }
}

fn type_error(ruby: &Ruby, value: Value, expected: &str) -> Error {
    Error::new(
        ruby.exception_type_error(),
        format!(
            "wrong argument type {} (expected {expected})",
            value.class()
        ),
    )
}

pub fn init(ruby: &Ruby, module: RModule) -> Result<(), Error> {
    let class = module.define_class("NamedNode", ruby.class_object())?;
    class.define_singleton_method("new", function!(NamedNode::new, 1))?;
    class.define_method("value", method!(NamedNode::value, 0))?;
    class.define_method("to_s", method!(NamedNode::to_s, 0))?;
    class.define_method("inspect", method!(NamedNode::inspect, 0))?;
    class.define_method("==", method!(NamedNode::equals, 1))?;
    class.define_method("eql?", method!(NamedNode::equals, 1))?;
    class.define_method("hash", method!(NamedNode::hash, 0))?;
    define_copying(class)?;

    let class = module.define_class("BlankNode", ruby.class_object())?;
    class.define_singleton_method("new", function!(BlankNode::new, -1))?;
    class.define_method("value", method!(BlankNode::value, 0))?;
    class.define_method("to_s", method!(BlankNode::to_s, 0))?;
    class.define_method("inspect", method!(BlankNode::inspect, 0))?;
    class.define_method("==", method!(BlankNode::equals, 1))?;
    class.define_method("eql?", method!(BlankNode::equals, 1))?;
    class.define_method("hash", method!(BlankNode::hash, 0))?;
    define_copying(class)?;

    let class = module.define_class("Literal", ruby.class_object())?;
    class.define_singleton_method("new", function!(Literal::new, -1))?;
    class.define_method("value", method!(Literal::value, 0))?;
    class.define_method("datatype", method!(Literal::datatype, 0))?;
    class.define_method("language", method!(Literal::language, 0))?;
    class.define_method("to_s", method!(Literal::to_s, 0))?;
    class.define_method("inspect", method!(Literal::inspect, 0))?;
    class.define_method("==", method!(Literal::equals, 1))?;
    class.define_method("eql?", method!(Literal::equals, 1))?;
    class.define_method("hash", method!(Literal::hash, 0))?;
    define_copying(class)?;

    let class = module.define_class("Triple", ruby.class_object())?;
    class.define_singleton_method("new", function!(Triple::new, 3))?;
    class.define_method("subject", method!(Triple::subject, 0))?;
    class.define_method("predicate", method!(Triple::predicate, 0))?;
    class.define_method("object", method!(Triple::object, 0))?;
    class.define_method("to_s", method!(Triple::to_s, 0))?;
    class.define_method("inspect", method!(Triple::inspect, 0))?;
    class.define_method("==", method!(Triple::equals, 1))?;
    class.define_method("eql?", method!(Triple::equals, 1))?;
    class.define_method("hash", method!(Triple::hash, 0))?;
    define_copying(class)?;

    Ok(())
}
