require 'active_record'

module Previewify

  module Control

    def show_preview(show_preview = true)
      Thread.current['Previewify::show_preview'] = show_preview
    end

  end

  class Options

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
      @options_hash[:published_flag_attribute_name] || 'latest'
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

  module InstanceMethods

    def self.included(target)

      # These methods are added to the previewified class:
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

        def self.show_preview?
          Thread.current['Previewify::show_preview'] || false
        end

        def self.delegate_to_published_version
          !show_preview? && self != published_version_class
        end

      end
    end

  end


  module ActiveRecord

    def previewify(options = {})

      cattr_accessor :previewify_options
      self.previewify_options = ::Previewify::Options.new(options, primary_key, table_name, columns)

      include Previewify::InstanceMethods

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

      const_set(previewify_options.published_version_class_name, Class.new(self)).class_eval do

        set_table_name(previewify_options.published_version_table_name)

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

        if previewify_options.preview_only_methods.present?
          previewify_options.preview_only_methods.each do |preview_only_method|
            undef_method(preview_only_method)
          end
        end

        if previewify_options.published_only_methods.present?
          previewify_options.published_only_methods.each do |published_only_method|
            class_variable_set("@@#{published_only_method}_method", self.instance_method(published_only_method))
            define_method("#{published_only_method}") do |*args|
              self.class.class_variable_get("@@#{published_only_method}_method").bind(self).call(*args)
            end
          end
        end

        cattr_accessor :previewify_options

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

      def published_version_class
        const_get previewify_options.published_version_class_name
      end

      published_version_class.previewify_options = previewify_options

      if previewify_options.published_only_methods.present?
        previewify_options.published_only_methods.each do |published_only_method|
          remove_method(published_only_method)
        end
      end

    end

  end
end


ActiveRecord::Base.extend Previewify::ActiveRecord

