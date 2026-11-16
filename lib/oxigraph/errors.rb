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
end
