# frozen_string_literal: true

require_relative "oxigraph/version"
require_relative "oxigraph/errors"
require_relative "oxigraph/load_summary"

# The extension raises the error classes and builds a LoadSummary, so it loads
# after they exist. A precompiled gem ships one extension for each Ruby minor
# version, in a directory named for it; a gem compiled at install time has
# one, beside this file's directory. Only a missing file falls back, so an
# extension that is present and fails to load reports its own error.
versioned_extension = "oxigraph/#{RUBY_VERSION[/\A\d+\.\d+/]}/oxigraph"
begin
  require versioned_extension
rescue LoadError => error
  raise unless error.path == versioned_extension

  require "oxigraph/oxigraph"
end

require_relative "oxigraph/store"
