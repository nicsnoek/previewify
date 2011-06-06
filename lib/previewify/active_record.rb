require 'active_record'
require 'previewify/config'
require 'previewify/previewified_methods'
require 'previewify/published_versions_class'

module Previewify
  module ActiveRecord

    def previewify(options = {})

      cattr_accessor :previewify_config do
        Previewify::Config.new(options, primary_key, table_name)
      end

      def create_published_versions_table
        connection.create_table(previewify_config.published_version_table_name, :primary_key => previewify_config.published_version_primary_key_name) do |t|
          t.column previewify_config.version_attribute_name, :integer
          t.column previewify_config.published_flag_attribute_name, :boolean
          t.column previewify_config.published_on_attribute_name, :timestamp
        end
        published_columns.each do |published_column|
          published_column_name = published_column.name == 'id' ? previewify_config.mapped_name_for_id : published_column.name
          connection.add_column previewify_config.published_version_table_name, published_column_name, published_column.type,
                                :limit => published_column.limit,
                                :scale => published_column.scale,
                                :precision => published_column.precision
        end
        # TODO: Index on (primary_key, published_flag)
        published_version_class.perform_class_initialisation_that_requires_table_to_exist()
      end

      def drop_published_versions_table
        connection.drop_table(previewify_config.published_version_table_name)
      end

      include Previewify::PreviewifiedMethods

      create_published_versions_class

      def published_version_class
        const_get previewify_config.published_version_class_name
      end

      remove_methods_that_are_for_published_class_only

    end

    private

    def remove_methods_that_are_for_published_class_only
      if previewify_config.published_only_method_names.present?
        previewify_config.published_only_method_names.each do |published_only_method|
          remove_method(published_only_method)
        end
      end
    end

    def published_columns
      return columns if previewify_config.preview_only_attribute_names.blank?
      columns.reject { |column|
        previewify_config.preview_only_attribute_names.include? column.name.to_sym
      }
    end



  end
end


ActiveRecord::Base.extend Previewify::ActiveRecord
