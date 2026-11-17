# frozen_string_literal: true

module Oxigraph
  # What Store#load learned from its input: the prefixes it declared, as a
  # frozen Hash of prefix name to namespace IRI, and the base IRI in effect at
  # its end, or +nil+.
  LoadSummary = Data.define(:prefixes, :base_iri)
end
