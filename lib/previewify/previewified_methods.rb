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
          if !delegate_to_published_version
            super(*args)
          else
            found = super(*args)
            raise ::ActiveRecord::RecordNotFound if args_is_ids(args) && !has_latest_published(found)
            return nil unless found.present?
            latest_published_from(found)
          end
        end

        def self.args_is_ids(args)
          !(args.last.is_a?(Hash) && args.last.extractable_options?)
        end

        def self.latest_published_from(result)
          if result.is_a? Array
            result.map(&:latest_published).compact
          else
            result.latest_published
          end
        end

        def self.has_latest_published(result)
          if result.is_a? Array
            result.all?{|item| item.latest_published.present?}
          else
            result.latest_published.present?
          end
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
          return latest_published.published_attributes_excluding_primary_key != self.published_attributes_excluding_primary_key
        end

        def revert_to_version!(version_number)
          version = self.class.published_version_class.specific_version_by_primary_key(primary_key_value, version_number)
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

        def self.delegate_to_published_version
          !Control.show_preview? && self != published_version_class
        end

      end
    end

  end
end