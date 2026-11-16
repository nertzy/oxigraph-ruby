# frozen_string_literal: true

require_relative "oxigraph/version"

module Oxigraph
  class Error < StandardError; end
end

# The extension raises Oxigraph::Error, so it loads after the class exists.
require "oxigraph/oxigraph"
