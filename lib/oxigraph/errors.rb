# frozen_string_literal: true

module Oxigraph
  # The base class of every error this gem raises on its own account.
  class Error < StandardError; end

  # Raised when RDF input is malformed. +line+ and +column+ count from one and
  # are +nil+ when the parser reports no position.
  class ParseError < Error
    attr_reader :line, :column

    def initialize(message = nil, line: nil, column: nil)
      super(message)
      @line = line
      @column = column
    end
  end

  # Raised when a SPARQL query or update does not parse. Its line and column
  # say where, counted from one; both are nil for an error that has no
  # position.
  class QuerySyntaxError < Error
    attr_reader :line, :column

    def initialize(message = nil, line: nil, column: nil)
      super(message)
      @line = line
      @column = column
    end
  end

  # Raised when a query fails while it runs.
  class QueryEvaluationError < Error; end

  # Raised for a query that uses a feature this gem leaves out on purpose,
  # which is SERVICE.
  class UnsupportedError < Error; end
end
