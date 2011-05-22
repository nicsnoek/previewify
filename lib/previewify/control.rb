module Previewify
  module Control

    def show_preview(preview_mode = true)
      Previewify::Control.show_preview(preview_mode)
    end

    def self.show_preview(preview_mode = true)
      Thread.current[KEY] = preview_mode
    end

    def show_preview?
      Previewify::Control.show_preview?
    end

    def self.show_preview?
      Thread.current[KEY] || false
    end

    private

    KEY = 'Previewify::show_preview'

  end
end