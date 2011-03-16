module Previewify
  module Control

    def show_preview(show_preview = true)
      Thread.current['Previewify::show_preview'] = show_preview
    end

    def show_preview?
      Thread.current['Previewify::show_preview'] || false
    end

  end
end