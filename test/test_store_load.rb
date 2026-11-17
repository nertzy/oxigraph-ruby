# frozen_string_literal: true

require "test_helper"
require "pathname"
require "stringio"
require "tempfile"

class TestStoreLoad < Minitest::Test
  TURTLE = <<~TURTLE
    @prefix ex: <http://example.com/> .
    @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
    ex:a rdfs:subClassOf ex:b .
    ex:b rdfs:subClassOf ex:c .
  TURTLE

  RDF_XML = <<~XML
    <?xml version="1.0"?>
    <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:ex="http://example.com/">
      <rdf:Description rdf:about="http://example.com/a">
        <ex:label>a</ex:label>
      </rdf:Description>
    </rdf:RDF>
  XML

  # Answers `read` like an IO and records how it was asked.
  class RecordingReader
    attr_reader :lengths

    def initialize(content)
      @io = StringIO.new(content)
      @lengths = []
    end

    def read(length)
      @lengths << length
      @io.read(length)
    end
  end

  def setup
    @store = Oxigraph::Store.new
  end

  def test_loads_rdf_content_from_a_string
    @store.load(TURTLE, format: :turtle)

    assert_equal 2, @store.size
  end

  def test_loads_from_an_io
    @store.load(StringIO.new(TURTLE), format: :turtle)

    assert_equal 2, @store.size
  end

  def test_loads_from_a_path_and_takes_the_format_from_its_extension
    with_file(TURTLE, ".ttl") { |path| @store.load(path: path) }

    assert_equal 2, @store.size
  end

  def test_loads_from_a_pathname
    with_file(TURTLE, ".ttl") { |path| @store.load(path: Pathname(path)) }

    assert_equal 2, @store.size
  end

  def test_an_explicit_format_overrides_the_extension
    with_file(RDF_XML, ".owl") { |path| @store.load(path: path, format: :rdf_xml) }

    assert_equal 1, @store.size
  end

  def test_loads_every_supported_format
    triple = "<http://example.com/a> <http://example.com/p> <http://example.com/b> ."
    json_ld = '{"@id": "http://example.com/a", "http://example.com/p": {"@id": "http://example.com/b"}}'
    contents = {
      turtle: triple, n_triples: triple, n_quads: triple, trig: triple, n3: triple,
      rdf_xml: RDF_XML, json_ld: json_ld
    }

    contents.each do |format, content|
      store = Oxigraph::Store.new
      store.load(content, format: format)

      assert_equal 1, store.size, "loading #{format}"
    end
  end

  def test_keeps_graph_names_from_a_format_that_carries_them
    @store.load(<<~NQUADS, format: :n_quads)
      <http://example.com/a> <http://example.com/p> <http://example.com/b> .
      <http://example.com/a> <http://example.com/p> <http://example.com/b> <http://example.com/g> .
    NQUADS

    assert_equal 2, @store.size
  end

  def test_loading_the_same_data_twice_adds_nothing
    2.times { @store.load(TURTLE, format: :turtle) }

    assert_equal 2, @store.size
  end

  def test_scopes_a_blank_node_label_to_one_load
    document = "_:a <http://example.com/p> <http://example.com/o> .\n" * 2

    @store.load(document, format: :n_triples)

    assert_equal 1, @store.size

    @store.load(document, format: :n_triples)

    assert_equal 2, @store.size
  end

  def test_resolves_relative_iris_against_a_base_iri
    @store.load("<a> <p> <b> .", format: :turtle, base_iri: "http://example.com/")

    assert_equal 1, @store.size
  end

  def test_reports_the_prefixes_the_input_declares
    summary = @store.load(TURTLE, format: :turtle)

    assert_equal(
      {"ex" => "http://example.com/", "rdfs" => "http://www.w3.org/2000/01/rdf-schema#"},
      summary.prefixes
    )
    assert_predicate summary.prefixes, :frozen?
  end

  def test_reports_no_prefixes_for_rdf_xml
    assert_empty @store.load(RDF_XML, format: :rdf_xml).prefixes
  end

  def test_reports_the_base_iri_the_input_declares
    summary = @store.load("@base <http://example.com/> . <a> <p> <b> .", format: :turtle)

    assert_equal "http://example.com/", summary.base_iri
  end

  def test_reports_the_base_iri_it_was_given
    summary = @store.load("<a> <p> <b> .", format: :turtle, base_iri: "http://example.com/")

    assert_equal "http://example.com/", summary.base_iri
  end

  def test_reports_no_base_iri_when_there_is_none
    assert_nil @store.load(TURTLE, format: :turtle).base_iri
  end

  def test_reads_an_io_in_chunks
    line = "<http://example.com/a> <http://example.com/p> \"%06d\" .\n"
    reader = RecordingReader.new(Array.new(5_000) { |number| line % number }.join)

    @store.load(reader, format: :n_triples)

    assert_equal 5_000, @store.size
    assert_operator reader.lengths.size, :>, 2
    assert_operator reader.lengths.max, :<=, 65_536
  end

  def test_raises_a_parse_error_with_the_position_of_the_mistake
    error = assert_raises(Oxigraph::ParseError) do
      @store.load("<http://example.com/a> <http://example.com/p> <http://example.com/b> .\n<http://example.com/a> oops", format: :turtle)
    end

    assert_kind_of Oxigraph::Error, error
    assert_equal 2, error.line
    assert_equal 24, error.column
    refute_empty error.message
  end

  def test_a_failed_load_leaves_the_store_unchanged
    @store.load(TURTLE, format: :turtle)

    assert_raises(Oxigraph::ParseError) do
      @store.load("<http://example.com/x> <http://example.com/p> <http://example.com/y> .\noops", format: :turtle)
    end

    assert_equal 2, @store.size
  end

  def test_rejects_a_relative_iri_without_a_base_iri
    assert_raises(Oxigraph::ParseError) { @store.load("<a> <p> <b> .", format: :turtle) }
  end

  def test_raises_what_the_reader_raises
    reader = Object.new
    def reader.read(_length) = raise(IOError, "the disk caught fire")

    error = assert_raises(IOError) { @store.load(reader, format: :turtle) }

    assert_equal "the disk caught fire", error.message
    assert_empty @store
  end

  def test_keeps_nothing_from_a_load_whose_reader_fails_partway
    @store.load(TURTLE, format: :turtle)
    failure = IOError.new("the disk caught fire")
    chunks = [
      "<http://example.com/x> <http://example.com/p> <http://example.com/y> .\n",
      "<http://example.com/y> <http://example.com/p> <http://example.com/z> .\n"
    ]
    reader = Object.new
    reader.define_singleton_method(:read) { |_length| chunks.shift || raise(failure) }

    error = assert_raises(IOError) { @store.load(reader, format: :n_triples) }

    assert_same failure, error
    assert_empty chunks
    assert_equal 2, @store.size
  end

  def test_rejects_a_reader_that_returns_something_other_than_a_string
    reader = Object.new
    def reader.read(_length) = 42

    assert_raises(TypeError) { @store.load(reader, format: :turtle) }
  end

  def test_raises_the_system_error_for_a_missing_file
    assert_raises(Errno::ENOENT) { @store.load(path: File.join(Dir.tmpdir, "oxigraph-no-such-file.ttl")) }
  end

  def test_requires_a_format_with_input
    error = assert_raises(ArgumentError) { @store.load(TURTLE) }

    assert_match(/format/, error.message)
  end

  def test_rejects_a_path_whose_extension_names_no_format
    error = assert_raises(ArgumentError) do
      with_file(RDF_XML, ".owl") { |path| @store.load(path: path) }
    end

    assert_match(/\.owl/, error.message)
  end

  def test_rejects_an_unknown_format
    error = assert_raises(ArgumentError) { @store.load(TURTLE, format: :csv) }

    assert_match(/csv/, error.message)
  end

  def test_rejects_a_format_that_is_not_a_symbol
    assert_raises(TypeError) { @store.load(TURTLE, format: "turtle") }
  end

  def test_rejects_both_input_and_a_path
    assert_raises(ArgumentError) { @store.load(TURTLE, format: :turtle, path: "data.ttl") }
  end

  def test_rejects_neither_input_nor_a_path
    assert_raises(ArgumentError) { @store.load(format: :turtle) }
  end

  def test_rejects_input_that_is_neither_a_string_nor_a_reader
    assert_raises(TypeError) { @store.load(42, format: :turtle) }
  end

  def test_rejects_an_invalid_base_iri
    assert_raises(ArgumentError) { @store.load(TURTLE, format: :turtle, base_iri: "not an iri") }
  end

  private

  def with_file(content, extension)
    Tempfile.create(["oxigraph", extension]) do |file|
      file.write(content)
      file.close
      yield file.path
    end
  end
end
