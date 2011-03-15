require 'active_record'
require 'previewify/previewified_methods'

module Previewify

  module ActiveRecord

    def previewify(options = {})

      cattr_accessor :previewify_options do
        Previewify::Options.new(options, primary_key, table_name, columns)
      end

      include Previewify::PreviewifiedMethods

      def create_published_versions_table
        connection.create_table(previewify_options.published_version_table_name, :primary_key => previewify_options.published_version_primary_key_attribute_name) do |t|
          t.column previewify_options.version_attribute_name, :integer
          t.column previewify_options.published_flag_attribute_name, :boolean
          t.column previewify_options.published_on_attribute_name, :timestamp
        end
        previewify_options.published_columns.each do |published_column|
          connection.add_column previewify_options.published_version_table_name, published_column.name, published_column.type,
                                :limit => published_column.limit,
                                :scale => published_column.scale,
                                :precision => published_column.precision
        end
        # TODO: Index on (primary_key, published_flag)
        published_version_class.setup_scope_to_default_to_latest
      end

      def drop_published_versions_table
        connection.drop_table(previewify_options.published_version_table_name)
      end

      create_published_versions_class(previewify_options)

      def published_version_class
        const_get previewify_options.published_version_class_name
      end

      remove_methods_that_are_for_published_class_only(previewify_options)

    end

    private

    def remove_methods_that_are_for_published_class_only(previewify_options)
      if previewify_options.published_only_methods.present?
        previewify_options.published_only_methods.each do |published_only_method|
          remove_method(published_only_method)
        end
      end
    end

    def create_published_versions_class(previewify_options_arg)
      const_set(previewify_options_arg.published_version_class_name, Class.new(self)).class_eval do

        set_table_name(previewify_options_arg.published_version_table_name)

        def self.setup_scope_to_default_to_latest
          default_scope :conditions => ["#{previewify_options.published_flag_attribute_name} = true"]
        end

        begin
          setup_scope_to_default_to_latest
        rescue
          # published versions table does not exists,
          # the scope will be re-created when the table is created.
        end

        undef published_on #Must undefine published_on to avoid infinite recursion. This class defines its own published_on attribute

        if previewify_options_arg.preview_only_methods.present?
          previewify_options_arg.preview_only_methods.each do |preview_only_method|
            undef_method(preview_only_method)
          end
        end

        if previewify_options_arg.published_only_methods.present?
          previewify_options_arg.published_only_methods.each do |published_only_method|
            class_variable_set("@@#{published_only_method}_method", self.instance_method(published_only_method))
            define_method("#{published_only_method}") do |*args|
              self.class.class_variable_get("@@#{published_only_method}_method").bind(self).call(*args)
            end
          end
        end

        def self.publish(preview, version)
          #Note: Can not set to readonly when .previewify is called as the published version table will not yet exist at that point'
          self.columns.each { |column|
            self.attr_readonly(column.name) unless column.name == previewify_options.published_flag_attribute_name
          }

          attributes_to_publish = previewify_options.published_attributes(preview.attributes)
          attributes_to_publish.merge!(
              previewify_options.version_attribute_name => version,
              previewify_options.published_flag_attribute_name => true,
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
          update_attribute(previewify_options.published_flag_attribute_name, false)
        end

        def published_attributes
          attributes.reject { |key|
            previewify_options.published_version_metainformation_attributes.include?(key)
          }
        end

        def self.latest_published_by_primary_key(primary_key_value)
          find(:first, :conditions => ["#{previewify_options.primary_key_attribute_name} = ?", primary_key_value])
        end

        def self.specific_version_by_primary_key(primary_key_value, version_number)
          with_exclusive_scope do
            find(:first, :conditions => ["#{previewify_options.primary_key_attribute_name} = ? AND #{previewify_options.version_attribute_name} = ?", primary_key_value, version_number])
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


ActiveRecord::Base.extend Previewify::ActiveRecord
