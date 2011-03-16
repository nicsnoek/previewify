module Previewify
  module ActiveRecord

    private

    def create_published_versions_class
      const_set(previewify_config.published_version_class_name, Class.new(self)).class_eval do

        set_table_name(previewify_config.published_version_table_name)

        def self.setup_scope_to_default_to_latest
          default_scope :conditions => "#{previewify_config.published_flag_attribute_name} = true"
        end

        begin
          setup_scope_to_default_to_latest
        rescue
          # published versions table does not exists,
          # the default scope will be re-created when the table is created.
        end

        undef published_on #Must undefine published_on to avoid infinite recursion. This class defines its own published_on attribute

        if previewify_config.preview_only_methods.present?
          previewify_config.preview_only_methods.each do |preview_only_method|
            undef_method(preview_only_method)
          end
        end

        if previewify_config.published_only_methods.present?
          previewify_config.published_only_methods.each do |published_only_method|
            class_variable_set("@@#{published_only_method}_method", self.instance_method(published_only_method))
            define_method("#{published_only_method}") do |*args|
              self.class.class_variable_get("@@#{published_only_method}_method").bind(self).call(*args)
            end
          end
        end

        def self.publish(preview, version)
          #Note: Can not set to readonly when .previewify is called as the published version table will not yet exist at that point'
          self.columns.each { |column|
            self.attr_readonly(column.name) unless column.name == previewify_config.published_flag_attribute_name
          }

          attributes_to_publish = previewify_config.published_attributes(preview.attributes)
          attributes_to_publish.merge!(
              previewify_config.version_attribute_name => version,
              previewify_config.published_flag_attribute_name => true,
              :published_on => Time.now
          )
          published_version = self.new(attributes_to_publish)
          if preview.respond_to?(:id)
            published_version.id = preview.id # won't mass-assign
          end
          published_version.save!
          return published_version
        end

        def take_down!
          update_attribute(previewify_config.published_flag_attribute_name, false)
        end

        def published_attributes
          attributes.reject { |key|
            previewify_config.published_version_metainformation_attributes.include?(key)
          }
        end

        def self.latest_published_by_primary_key(primary_key_value)
          find(:first, :conditions => ["#{previewify_config.primary_key_attribute_name} = ?", primary_key_value])
        end

        def self.specific_version_by_primary_key(primary_key_value, version_number)
          with_exclusive_scope do
            find(:first, :conditions => ["#{previewify_config.primary_key_attribute_name} = ? AND #{previewify_config.version_attribute_name} = ?", primary_key_value, version_number])
          end
        end

        def self.all_versions_by_primary_key(primary_key_value)
          with_exclusive_scope do
            find(:all, :conditions => ["#{previewify_config.primary_key_attribute_name} = ?", primary_key_value])
          end
        end

        def self.take_down(pk_to_take_down)
          take_down_candidate = latest_published_by_primary_key(pk_to_take_down)
          take_down_candidate.try(:take_down!)
          take_down_candidate
        end

      end

    end


  end
end