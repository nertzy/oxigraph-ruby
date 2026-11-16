# frozen_string_literal: true

module Oxigraph
  class Store
    # Loads RDF and returns a LoadSummary.
    #
    # Give either +input+, a String of RDF content or an object that responds
    # to +read+ as an IO does, or +path:+, the name of a file. +format:+ is one
    # of +:turtle+, +:rdf_xml+, +:n_triples+, +:n_quads+, +:trig+, +:n3+, and
    # +:json_ld+. It is required with +input+; with +path:+ it defaults to the
    # format the file extension names.
    #
    # A load is all or nothing: malformed input raises ParseError and leaves
    # the store unchanged.
    def load(input = nil, format: nil, path: nil, base_iri: nil)
      if path.nil?
        raise ArgumentError, "give RDF content, a reader, or path:" if input.nil?

        load_input(input, format, nil, base_iri)
      else
        raise ArgumentError, "give input or path:, not both" unless input.nil?

        File.open(path, "rb") { |file| load_input(file, format, File.extname(path), base_iri) }
      end
    end
  end
end
