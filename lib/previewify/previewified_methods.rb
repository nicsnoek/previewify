module Previewify

  # These methods are added to the previewified class:
  module PreviewifiedMethods

    def self.included(target)

      target.class_eval do

        delegate :published_on, :to => :latest_published, :allow_nil => true

        def latest_published
          self.class.published_version_class.latest_published_by_primary_key(primary_key_value)
        end

        def self.all(*args)
          delegate_to_published_version ? published_version_class.all(*args) : super(*args)
        end

        def self.find(*args)
          delegate_to_published_version ? published_version_class.find(*args) : super(*args)
        end

        def self.method_missing(*args)
          delegate_to_published_version ? published_version_class.send(*args) : super(*args)
        end

        def publish!
          latest_published = take_down!
          latest_published_version = latest_published.try(:version) || 0
          self.class.published_version_class.publish(self, latest_published_version + 1)
        end

        def take_down!
          self.class.published_version_class.take_down(primary_key_value)
        end

        def published?
          latest_published.present?
        end

        def has_unpublished_changes?
          return false if !published?
          return latest_published.published_attributes != previewify_options.published_attributes(attributes)
        end

        def revert_to_version!(version_number)
          version = self.class.published_version_class.specific_version_by_primary_key(primary_key_value, version_number)
          update_attributes!(version.published_attributes)
        end

        private

        def primary_key_value
          primary_key_name = self.class.previewify_options.primary_key_attribute_name
          self.send(primary_key_name)
        end

        def self.delegate_to_published_version
          !Previewify::Control.show_preview? && self != published_version_class
        end

      end
    end

  end
end