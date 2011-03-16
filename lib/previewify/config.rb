module Previewify

  class Config

    def initialize(options_hash, primary_key_name, preview_table_name, preview_columns)
      @options_hash = options_hash
      @primary_key_name = primary_key_name
      @preview_table_name = preview_table_name
      @preview_columns = preview_columns
    end

    def published_version_table_name
      "#{@preview_table_name.singularize}_#{published_version_class_name.underscore.pluralize}"
    end

    def published_version_class_name
      @options_hash[:published_version_class_name] || "PublishedVersion"
    end

      def published_flag_attribute_name
      @options_hash[:published_flag_attribute_name] || 'published'
    end

    def version_attribute_name
      'version'
    end

    def published_version_primary_key_attribute_name
      'published_id'
    end

    def primary_key_attribute_name
      @primary_key_name
    end

    def published_on_attribute_name
      'published_on'
    end

    def published_columns
      preview_only_columns = @options_hash[:preview_only_attributes]
      return @preview_columns if preview_only_columns.blank?
      @preview_columns.reject { |column|
        preview_only_columns.include? column.name.to_sym
      }
    end

    def published_attributes(all_preview_attributes)
      preview_only_columns = @options_hash[:preview_only_attributes]
      return all_preview_attributes if preview_only_columns.blank?
      all_preview_attributes.reject { |key|
        preview_only_columns.include? key.to_sym
      }
    end

    def published_version_metainformation_attributes
      [
          published_version_primary_key_attribute_name,
          version_attribute_name,
          published_flag_attribute_name,
          published_on_attribute_name
      ]
    end

    def published_only_methods
      @options_hash[:published_only_methods]
    end

    def preview_only_methods
      @options_hash[:preview_only_methods]
    end


  end
end