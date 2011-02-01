require 'active_record'

module Previewify

  module Control

    def show_preview(show_preview = true)
      Thread.current['Previewify::show_preview'] = show_preview
    end

  end

  class Options

    def initialize(options_hash, preview_table_name, preview_columns)
      @options_hash       = options_hash
      @preview_table_name = preview_table_name
      @preview_columns    = preview_columns
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
      @options_hash[:primary_key] || 'id'
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


  end

  module InstanceMethods

    def self.included(target)

      # These methods are added to the previewified class:
      target.class_eval do

        delegate :published_on, :to => :latest_published, :allow_nil => true

        def latest_published
          primary_key_name  = self.class.previewify_options.primary_key_attribute_name
          primary_key_value = self.send(primary_key_name)

          @latest_published ||= self.class.published_version_class.latest_published_by_primary_key(primary_key_value)
        end

        def self.find_latest_published(*args)
          latest_published = published_version_class.latest_published_by_primary_key(*args)
          raise ::ActiveRecord::RecordNotFound unless latest_published.present?
          latest_published
        end

        def self.find(*args)
          show_preview? ? super(*args) : find_latest_published(*args)
        end

        def publish!
          latest_published         = take_down!
          latest_published_version = latest_published.try(:version) || 0
          self.class.published_version_class.publish(self, latest_published_version + 1)
        end

        def take_down!
          self.class.published_version_class.take_down(id)
        end

        def has_unpublished_changes?
          return false if latest_published.blank?
          return latest_published.published_attributes != previewify_options.published_attributes(attributes)
        end

        def revert_to_version!(version_number)
          version = self.class.published_version_class.specific_version_by_primary_key(id, version_number)
          update_attributes!(version.published_attributes)
        end

        private

        def self.show_preview?
          Thread.current['Previewify::show_preview'] || false
        end

      end
    end

  end


  module ActiveRecord

    def previewify(options = {})

      cattr_accessor :previewify_options
      self.previewify_options = ::Previewify::Options.new(options, table_name, columns)

      def create_published_versions_table
        connection.create_table(previewify_options.published_version_table_name, :primary_key => previewify_options.published_version_primary_key_attribute_name) do |t|
          t.column previewify_options.version_attribute_name, :integer
          t.column previewify_options.published_flag_attribute_name, :boolean
          t.column previewify_options.published_on_attribute_name, :timestamp
        end
        previewify_options.published_columns.each do |published_column|
          connection.add_column previewify_options.published_version_table_name, published_column.name, published_column.type,
                                :limit     => published_column.limit,
                                :scale     => published_column.scale,
                                :precision => published_column.precision
        end
      end

      def drop_published_versions_table
        connection.drop_table(previewify_options.published_version_table_name)
      end

      const_set(previewify_options.published_version_class_name, Class.new(::ActiveRecord::Base)).class_eval do

        named_scope :latest_published, lambda { |primary_key_value|
          {:conditions => ["#{previewify_options.primary_key_attribute_name} = ? AND #{previewify_options.published_flag_attribute_name} = true", primary_key_value]}
        }

        named_scope :version, lambda { |primary_key_value, version_number|
          {:conditions => ["#{previewify_options.primary_key_attribute_name} = ? AND #{previewify_options.version_attribute_name} = ?", primary_key_value, version_number]}
        }

        cattr_accessor :previewify_options

        def self.publish(preview, version)
          #Note: Can not set to readonly when .previewify is called as the published version table will not yet exist at that point'
          self.columns.each { |column|
            self.attr_readonly(column.name) unless column.name == previewify_options.published_flag_attribute_name
          }

          attributes_to_publish = previewify_options.published_attributes(preview.attributes)
          attributes_to_publish.merge!(
              previewify_options.version_attribute_name        => version,
              previewify_options.published_flag_attribute_name => true,
              :published_on                                    => Time.now
          )
          published_version    = self.new(attributes_to_publish)
          published_version.id = preview.id # won't mass-assign
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
          latest_published(primary_key_value)[0]
        end

        def self.specific_version_by_primary_key(primary_key_value, version_number)
          version(primary_key_value, version_number)[0]
        end

        def self.take_down(id_to_take_down)
          take_down_candidate = latest_published_by_primary_key(id_to_take_down)
          take_down_candidate.try(:take_down!)
          take_down_candidate
        end

      end

      def published_version_class
        const_get previewify_options.published_version_class_name
      end

      published_version_class.previewify_options = previewify_options

      include Previewify::InstanceMethods

    end

  end
end


ActiveRecord::Base.extend Previewify::ActiveRecord

#require 'previewify/controller'
#require 'previewify/activerecord'

#if defined? Rails
# include stuff?
#end
