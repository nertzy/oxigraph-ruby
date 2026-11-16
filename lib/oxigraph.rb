# frozen_string_literal: true

require_relative "oxigraph/version"
require_relative "oxigraph/errors"
require_relative "oxigraph/load_summary"

# The extension raises the error classes and builds a LoadSummary, so it loads
# after they exist.
require "oxigraph/oxigraph"

require_relative "oxigraph/store"
