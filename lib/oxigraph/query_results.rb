# frozen_string_literal: true

module Oxigraph
  # What QuerySolutions and QueryTriples share: results that arrive from the
  # store one at a time and can be read once.
  module QueryResults
    include Enumerable

    # Yields each result in turn, or returns an Enumerator without a block.
    # Reading a second time raises Error, whether or not the first reading
    # reached the end.
    def each
      return enum_for(:each) unless block_given?

      start_reading
      while (result = next_result)
        yield result
      end
      self
    end
  end

  class QuerySolutions
    include QueryResults
  end

  class QueryTriples
    include QueryResults
  end
end
