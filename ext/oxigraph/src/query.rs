use std::cell::{Cell, RefCell};

use magnus::{
    function, method, prelude::*, r_hash::ForEach, scan_args, typed_data::Obj, Error, RArray,
    RHash, RModule, RString, Ruby, Symbol, TryConvert, Value,
};
use oxigraph::sparql::{
    QueryResults, QuerySolution as Row, QuerySolutionIter, QueryTripleIter, SparqlEvaluator,
};
use oxigraph::store::Store;
use spargebra::algebra::{AggregateExpression, Expression, GraphPattern, OrderExpression};
use spargebra::SparqlParser;

use crate::error::{argument_error, error, named_error, query_syntax_error};
use crate::model::{frozen, term_to_value, triple_to_value};

/// A parsed SPARQL query, exposed to Ruby as `Oxigraph::Query`.
#[magnus::wrap(class = "Oxigraph::Query", free_immediately, size)]
pub struct Query {
    inner: spargebra::Query,
    /// Whether a `SERVICE` clause appears anywhere in the query.
    service: bool,
}

impl Query {
    fn parse(ruby: &Ruby, arguments: &[Value]) -> Result<Obj<Self>, Error> {
        let (text, parser) = text_and_parser(ruby, arguments)?;
        Ok(frozen(ruby, Self::from_text(ruby, parser, &text)?))
    }

    fn from_text(ruby: &Ruby, parser: SparqlParser, text: &str) -> Result<Self, Error> {
        let inner = parser
            .parse_query(text)
            .map_err(|cause| query_syntax_error(ruby, &cause))?;
        let service = pattern_has_service(pattern_of(&inner));
        Ok(Self { inner, service })
    }

    fn form(ruby: &Ruby, rb_self: &Self) -> Symbol {
        ruby.to_symbol(match rb_self.inner {
            spargebra::Query::Select { .. } => "select",
            spargebra::Query::Construct { .. } => "construct",
            spargebra::Query::Describe { .. } => "describe",
            spargebra::Query::Ask { .. } => "ask",
        })
    }

    fn has_service(&self) -> bool {
        self.service
    }

    fn has_dataset(&self) -> bool {
        match &self.inner {
            spargebra::Query::Select { dataset, .. }
            | spargebra::Query::Construct { dataset, .. }
            | spargebra::Query::Describe { dataset, .. }
            | spargebra::Query::Ask { dataset, .. } => dataset.is_some(),
        }
    }

    fn to_s(&self) -> String {
        self.inner.to_string()
    }

    fn inspect(&self) -> String {
        format!("#<Oxigraph::Query {}>", self.inner)
    }
}

/// A parsed SPARQL update, exposed to Ruby as `Oxigraph::Update`. It can be
/// recognized and printed, and nothing here runs it.
#[magnus::wrap(class = "Oxigraph::Update", free_immediately, size)]
pub struct Update {
    inner: spargebra::Update,
}

impl Update {
    fn parse(ruby: &Ruby, arguments: &[Value]) -> Result<Obj<Self>, Error> {
        let (text, parser) = text_and_parser(ruby, arguments)?;
        let inner = parser
            .parse_update(&text)
            .map_err(|cause| query_syntax_error(ruby, &cause))?;
        Ok(frozen(ruby, Self { inner }))
    }

    /// Upstream ends each operation with a line break, which the text of a
    /// single value has no use for.
    fn to_s(&self) -> String {
        self.inner.to_string().trim_end().to_owned()
    }

    fn inspect(&self) -> String {
        format!("#<Oxigraph::Update {}>", self.to_s())
    }
}

/// Reads the arguments that `Query.parse` and `Update.parse` share: the text,
/// then `base_iri:` and `prefixes:`.
fn text_and_parser(ruby: &Ruby, arguments: &[Value]) -> Result<(String, SparqlParser), Error> {
    let arguments = scan_args::scan_args::<(String,), (), (), (), RHash, ()>(arguments)?;
    let keywords = scan_args::get_kwargs::<
        _,
        (),
        (Option<Option<String>>, Option<Option<RHash>>),
        (),
    >(arguments.keywords, &[], &["base_iri", "prefixes"])?;
    let (base_iri, prefixes) = keywords.optional;

    let mut parser = SparqlParser::new();
    if let Some(base_iri) = base_iri.flatten() {
        parser = parser
            .with_base_iri(base_iri)
            .map_err(|cause| argument_error(ruby, cause))?;
    }
    if let Some(prefixes) = prefixes.flatten() {
        let mut declared = Vec::new();
        prefixes.foreach(|name: Value, iri: String| {
            let name = match Symbol::from_value(name) {
                Some(name) => name.name()?.into_owned(),
                None => String::try_convert(name)?,
            };
            declared.push((name, iri));
            Ok(ForEach::Continue)
        })?;
        for (name, iri) in declared {
            parser = parser
                .with_prefix(name, iri)
                .map_err(|cause| argument_error(ruby, cause))?;
        }
    }
    Ok((arguments.required.0, parser))
}

fn pattern_of(query: &spargebra::Query) -> &GraphPattern {
    match query {
        spargebra::Query::Select { pattern, .. }
        | spargebra::Query::Construct { pattern, .. }
        | spargebra::Query::Describe { pattern, .. }
        | spargebra::Query::Ask { pattern, .. } => pattern,
    }
}

/// Whether `pattern` holds a `SERVICE` clause at any depth. Both matches name
/// every variant, so a new kind of pattern or expression upstream stops the
/// build here until someone decides whether it can hold one.
fn pattern_has_service(pattern: &GraphPattern) -> bool {
    match pattern {
        GraphPattern::Service { .. } => true,
        GraphPattern::Bgp { .. } | GraphPattern::Path { .. } | GraphPattern::Values { .. } => false,
        GraphPattern::Join { left, right }
        | GraphPattern::Lateral { left, right }
        | GraphPattern::Union { left, right }
        | GraphPattern::Minus { left, right } => {
            pattern_has_service(left) || pattern_has_service(right)
        }
        GraphPattern::LeftJoin {
            left,
            right,
            expression,
        } => {
            pattern_has_service(left)
                || pattern_has_service(right)
                || expression.as_ref().is_some_and(expression_has_service)
        }
        GraphPattern::Filter { expr, inner } => {
            expression_has_service(expr) || pattern_has_service(inner)
        }
        GraphPattern::Extend {
            inner, expression, ..
        } => pattern_has_service(inner) || expression_has_service(expression),
        GraphPattern::OrderBy { inner, expression } => {
            pattern_has_service(inner)
                || expression.iter().any(|order| match order {
                    OrderExpression::Asc(expression) | OrderExpression::Desc(expression) => {
                        expression_has_service(expression)
                    }
                })
        }
        GraphPattern::Group {
            inner, aggregates, ..
        } => {
            pattern_has_service(inner)
                || aggregates.iter().any(|(_, aggregate)| match aggregate {
                    AggregateExpression::CountSolutions { .. } => false,
                    AggregateExpression::FunctionCall { expr, .. } => expression_has_service(expr),
                })
        }
        GraphPattern::Graph { inner, .. }
        | GraphPattern::Project { inner, .. }
        | GraphPattern::Distinct { inner }
        | GraphPattern::Reduced { inner }
        | GraphPattern::Slice { inner, .. } => pattern_has_service(inner),
    }
}

/// Whether `expression` holds a `SERVICE` clause, which it can only do inside
/// the pattern of an `EXISTS`.
fn expression_has_service(expression: &Expression) -> bool {
    match expression {
        Expression::Exists(pattern) => pattern_has_service(pattern),
        Expression::NamedNode(_)
        | Expression::Literal(_)
        | Expression::Variable(_)
        | Expression::Bound(_) => false,
        Expression::Or(left, right)
        | Expression::And(left, right)
        | Expression::Equal(left, right)
        | Expression::SameTerm(left, right)
        | Expression::Greater(left, right)
        | Expression::GreaterOrEqual(left, right)
        | Expression::Less(left, right)
        | Expression::LessOrEqual(left, right)
        | Expression::Add(left, right)
        | Expression::Subtract(left, right)
        | Expression::Multiply(left, right)
        | Expression::Divide(left, right) => {
            expression_has_service(left) || expression_has_service(right)
        }
        Expression::UnaryPlus(inner) | Expression::UnaryMinus(inner) | Expression::Not(inner) => {
            expression_has_service(inner)
        }
        Expression::In(tested, candidates) => {
            expression_has_service(tested) || candidates.iter().any(expression_has_service)
        }
        Expression::If(condition, then, otherwise) => {
            expression_has_service(condition)
                || expression_has_service(then)
                || expression_has_service(otherwise)
        }
        Expression::Coalesce(arguments) | Expression::FunctionCall(_, arguments) => {
            arguments.iter().any(expression_has_service)
        }
    }
}

/// Runs a query against `store` for `Store#query`. `query` is an
/// `Oxigraph::Query` or a `String` of SPARQL.
pub fn evaluate(ruby: &Ruby, store: &Store, query: Value) -> Result<Value, Error> {
    let parsed;
    let query = match <&Query>::try_convert(query) {
        Ok(query) => query,
        Err(_) => {
            let Some(text) = RString::from_value(query) else {
                return Err(Error::new(
                    ruby.exception_type_error(),
                    format!(
                        "wrong argument type {} (expected a String or Oxigraph::Query)",
                        query.class()
                    ),
                ));
            };
            parsed = Query::from_text(ruby, SparqlParser::new(), &text.to_string()?)?;
            &parsed
        }
    };
    // Refused before anything is evaluated: with no handler for it, a SERVICE
    // fails on its first row, but a SERVICE SILENT quietly matches nothing.
    if query.service {
        return Err(named_error(
            ruby,
            "UnsupportedError",
            "SERVICE is not supported: a query never opens a network connection",
        ));
    }

    let results = SparqlEvaluator::new()
        .for_query(query.inner.clone())
        .on_store(store)
        .execute()
        .map_err(|cause| named_error(ruby, "QueryEvaluationError", cause))?;
    Ok(match results {
        QueryResults::Boolean(answer) => ruby.into_value(answer),
        QueryResults::Solutions(solutions) => ruby
            .obj_wrap(QuerySolutions {
                variables: solutions
                    .variables()
                    .iter()
                    .map(|variable| variable.as_str().to_owned())
                    .collect(),
                rows: Rows::new(solutions),
            })
            .as_value(),
        QueryResults::Graph(triples) => ruby
            .obj_wrap(QueryTriples {
                rows: Rows::new(triples),
            })
            .as_value(),
    })
}

/// A result iterator that is read once, from Ruby, one row per call.
struct Rows<I> {
    iterator: RefCell<Option<I>>,
    started: Cell<bool>,
}

// SAFETY: upstream's result iterators are not `Send` because they hold `Rc`s.
// Every clone of those `Rc`s lives inside the iterator itself, and Ruby only
// calls into a wrapped object, or frees it, while it holds the GVL. So no two
// threads ever touch one at the same time, whichever thread that is. This
// stops being true if the extension ever evaluates a query with the GVL
// released.
unsafe impl<I> Send for Rows<I> {}

impl<I: Iterator<Item = Result<T, E>>, T, E: std::fmt::Display> Rows<I> {
    fn new(iterator: I) -> Self {
        Self {
            iterator: RefCell::new(Some(iterator)),
            started: Cell::new(false),
        }
    }

    /// Marks the rows as being read, and fails if they already were.
    fn start(&self, ruby: &Ruby) -> Result<(), Error> {
        if self.started.replace(true) {
            return Err(error(
                ruby,
                "query results can be read only once; run the query again to read them again",
            ));
        }
        Ok(())
    }

    /// The next row, or `None` once they are used up. The iterator is dropped
    /// at its end or at its first error, which frees its snapshot of the store.
    fn advance(&self, ruby: &Ruby) -> Result<Option<T>, Error> {
        let mut iterator = self.iterator.borrow_mut();
        match iterator.as_mut().and_then(Iterator::next) {
            Some(Ok(row)) => Ok(Some(row)),
            Some(Err(cause)) => {
                *iterator = None;
                Err(named_error(ruby, "QueryEvaluationError", cause))
            }
            None => {
                *iterator = None;
                Ok(None)
            }
        }
    }
}

/// The rows of a `SELECT`, exposed to Ruby as `Oxigraph::QuerySolutions`.
#[magnus::wrap(class = "Oxigraph::QuerySolutions", free_immediately, size)]
pub struct QuerySolutions {
    variables: Vec<String>,
    rows: Rows<QuerySolutionIter<'static>>,
}

impl QuerySolutions {
    fn variables(ruby: &Ruby, rb_self: &Self) -> RArray {
        ruby.ary_from_iter(rb_self.variables.iter().map(|name| ruby.to_symbol(name)))
    }

    fn start(ruby: &Ruby, rb_self: &Self) -> Result<(), Error> {
        rb_self.rows.start(ruby)
    }

    fn advance(ruby: &Ruby, rb_self: &Self) -> Result<Option<Obj<QuerySolution>>, Error> {
        let row = rb_self.rows.advance(ruby)?;
        Ok(row.map(|inner| frozen(ruby, QuerySolution { inner })))
    }
}

/// One row of a `SELECT`, exposed to Ruby as `Oxigraph::QuerySolution`.
#[magnus::wrap(class = "Oxigraph::QuerySolution", free_immediately, size)]
pub struct QuerySolution {
    inner: Row,
}

impl QuerySolution {
    fn get(ruby: &Ruby, rb_self: &Self, key: Value) -> Result<Option<Value>, Error> {
        let row = &rb_self.inner;
        let term = if let Some(position) = magnus::Integer::from_value(key) {
            usize::try_from(position.to_i64()?)
                .ok()
                .and_then(|position| row.get(position))
        } else {
            let name = if let Some(name) = Symbol::from_value(key) {
                name.name()?.into_owned()
            } else if let Some(name) = RString::from_value(key) {
                name.to_string()?
            } else {
                return Err(Error::new(
                    ruby.exception_type_error(),
                    format!(
                        "wrong argument type {} (expected a Symbol, a String, or an Integer)",
                        key.class()
                    ),
                ));
            };
            if !row
                .variables()
                .iter()
                .any(|variable| variable.as_str() == name)
            {
                return Err(Error::new(
                    ruby.exception_index_error(),
                    format!("the query selects no variable named {name}"),
                ));
            }
            row.get(name.as_str())
        };
        Ok(term.map(|term| term_to_value(ruby, term.clone())))
    }

    fn to_h(ruby: &Ruby, rb_self: &Self) -> Result<RHash, Error> {
        let row = &rb_self.inner;
        let bindings = ruby.hash_new();
        for (variable, term) in row.variables().iter().zip(row.values()) {
            bindings.aset(
                ruby.to_symbol(variable.as_str()),
                term.clone().map(|term| term_to_value(ruby, term)),
            )?;
        }
        Ok(bindings)
    }

    fn inspect(&self) -> String {
        let row = &self.inner;
        let mut text = String::from("#<Oxigraph::QuerySolution");
        for (variable, term) in row.variables().iter().zip(row.values()) {
            text.push(' ');
            text.push_str(variable.as_str());
            text.push('=');
            match term {
                Some(term) => text.push_str(&term.to_string()),
                None => text.push_str("nil"),
            }
        }
        text.push('>');
        text
    }
}

/// The triples of a `CONSTRUCT` or a `DESCRIBE`, exposed to Ruby as
/// `Oxigraph::QueryTriples`.
#[magnus::wrap(class = "Oxigraph::QueryTriples", free_immediately, size)]
pub struct QueryTriples {
    rows: Rows<QueryTripleIter<'static>>,
}

impl QueryTriples {
    fn start(ruby: &Ruby, rb_self: &Self) -> Result<(), Error> {
        rb_self.rows.start(ruby)
    }

    fn advance(ruby: &Ruby, rb_self: &Self) -> Result<Option<Value>, Error> {
        let row = rb_self.rows.advance(ruby)?;
        Ok(row.map(|triple| triple_to_value(ruby, triple)))
    }
}

/// None of these classes can be built from Ruby, so each loses its allocator
/// here, before `new` could make an instance with nothing inside it.
pub fn init(ruby: &Ruby, module: RModule) -> Result<(), Error> {
    let class = module.define_class("Query", ruby.class_object())?;
    class.undef_default_alloc_func();
    class.define_singleton_method("parse", function!(Query::parse, -1))?;
    class.define_method("form", method!(Query::form, 0))?;
    class.define_method("service?", method!(Query::has_service, 0))?;
    class.define_method("dataset?", method!(Query::has_dataset, 0))?;
    class.define_method("to_s", method!(Query::to_s, 0))?;
    class.define_method("inspect", method!(Query::inspect, 0))?;

    let class = module.define_class("Update", ruby.class_object())?;
    class.undef_default_alloc_func();
    class.define_singleton_method("parse", function!(Update::parse, -1))?;
    class.define_method("to_s", method!(Update::to_s, 0))?;
    class.define_method("inspect", method!(Update::inspect, 0))?;

    // `lib/oxigraph/query_results.rb` builds `each` on these two private
    // methods, so that Ruby does the yielding.
    let class = module.define_class("QuerySolutions", ruby.class_object())?;
    class.undef_default_alloc_func();
    class.define_method("variables", method!(QuerySolutions::variables, 0))?;
    class.define_private_method("start_reading", method!(QuerySolutions::start, 0))?;
    class.define_private_method("next_result", method!(QuerySolutions::advance, 0))?;

    let class = module.define_class("QueryTriples", ruby.class_object())?;
    class.undef_default_alloc_func();
    class.define_private_method("start_reading", method!(QueryTriples::start, 0))?;
    class.define_private_method("next_result", method!(QueryTriples::advance, 0))?;

    let class = module.define_class("QuerySolution", ruby.class_object())?;
    class.undef_default_alloc_func();
    class.define_method("[]", method!(QuerySolution::get, 1))?;
    class.define_method("to_h", method!(QuerySolution::to_h, 0))?;
    class.define_method("inspect", method!(QuerySolution::inspect, 0))?;

    Ok(())
}
