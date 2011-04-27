module Previewify

  class Config

    def initialize(options_hash, primary_key_name, preview_table_name)
      @options_hash = options_hash
      @primary_key_name = primary_key_name
      @preview_table_name = preview_table_name
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

    def published_version_metainformation_attributes
      [
          published_version_primary_key_attribute_name,
          version_attribute_name,
          published_flag_attribute_name,
          published_on_attribute_name
      ]
    end

    def preview_only_attribute_names
      @options_hash[:preview_only_attributes]
    end

    def preview_only_method_names
      @options_hash[:preview_only_methods]
    end

    def published_only_method_names
      @options_hash[:published_only_methods]
    end

  end
end