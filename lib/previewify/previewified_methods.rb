module Previewify

  # These methods are added to the previewified class:
  module PreviewifiedMethods

    def self.included(target)

      target.class_eval do

        class << self

          def find(*args)
            if delegate_to_published_version
              published_version_class.find(*args)
            else
              super(*args)
            end
          end

          # Overrides method in active_record/named_scope.rb, this allows most queries to switch over to
          # published_version_class when appropriate.
          def scoped(options = nil)
            delegate_to_published_version ? published_version_class.scoped(options) : super(options)
          end

          private

          def delegate_to_published_version
            !Control.show_preview? && self != published_version_class
          end

        end

        delegate previewify_config.published_on_attribute_name, :to => :latest_published, :allow_nil => true
        delegate previewify_config.version_attribute_name, :to => :latest_published, :allow_nil => true

        def latest_published
          self.class.published_version_class.latest_published_by_primary_key(primary_key_value)
        end

        def preview_object?
          true
        end

        def last_published_version_number
          last_published_version = versions.last
          last_published_version.present? ? last_published_version.send(previewify_config.version_attribute_name) : 0
        end

        def publish!
          raise ::Previewify::ActiveRecord::RecordNotPublished if new_record?
          latest_published = take_down!
          latest_published_version = latest_published.present? ? latest_published.send(previewify_config.version_attribute_name) : last_published_version_number
          self.class.published_version_class.publish(self, latest_published_version + 1)
        end

        def versions
          self.class.published_version_class.all_versions_by_primary_key(primary_key_value)
        end

        def version(version_number)
          #self.class.published_version_class.all_versions_by_primary_key(primary_key_value).where("#{previewify_config.version_attribute_name}" => version_number)
          self.class.published_version_class.version_by_primary_key(primary_key_value, version_number)
        end

        def take_down!
          self.class.published_version_class.take_down(primary_key_value)
        end

        def published?
          latest_published.present?
        end

        def has_unpublished_changes?
          return false if !published?
          return latest_published.published_attributes_excluding_primary_key != self.published_attributes_excluding_primary_key
        end

        def revert_to_version_number!(version_number)
          version = self.class.published_version_class.version_by_primary_key(primary_key_value, version_number)
          update_attributes!(version.published_attributes_excluding_primary_key)
        end

        def published_attributes
          return attributes if previewify_config.preview_only_attribute_names.blank?
          attributes.reject { |key|
            previewify_config.preview_only_attribute_names.include? key.to_sym
          }
        end

        def published_attributes_excluding_primary_key
          #TODO: what to do about 'id' ?'
          published_attributes.reject{|name| name == previewify_config.mapped_name_for_id || name == 'id' }
        end

        private

        def primary_key_value
#          primary_key_name = self.class.previewify_config.primary_key_attribute_name
          self.send(:id)
          #Note: ActiveRecord always maps pk to id
        end

      end
    end

  end
end