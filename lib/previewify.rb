require 'active_record'

module Previewify

  module Control

    def show_preview(show_preview = true)
      Thread.current['Previewify::show_preview']  =  show_preview
    end

  end

  module Methods

    def self.included(target)

      # These methods are added to the previewified class:
      target.class_eval do

        delegate :published_on, :to => :latest_published, :allow_nil => true

        def latest_published
          primary_key_name  = self.class.primary_key
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
          latest_published = take_down!
          latest_published_version = latest_published.try(:version) || 0
          self.class.published_version_class.create(attributes.merge(self.class.version_attribute_name => latest_published_version + 1))
        end

        def take_down!
          self.class.published_version_class.take_down(id)
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
      @options = options

      # These will be configurable from the options:

      def published_version_table_name
        "#{table_name.singularize}_published_versions"
      end

      def published_version_class_name
        "PublishedVersion"
      end

      def published_flag_attribute_name
        'latest'
      end

      def version_attribute_name
        'version'
      end

      def published_version_primary_key_attribute_name
        'published_id'
      end

      def primary_key_attribute_name
        'id'
      end

      def published_on_attribute_name
        'published_on'
      end

      def published_columns
        columns
      end

      ################################################

      def published_version_metainformation_attributes
        [
          published_version_primary_key_attribute_name,
          version_attribute_name,
          published_flag_attribute_name,
          published_on_attribute_name
        ]
      end

      def create_published_versions_table
        connection.create_table(published_version_table_name, :primary_key => published_version_primary_key_attribute_name) do |t|
          t.column version_attribute_name, :integer
          t.column published_flag_attribute_name, :boolean
          t.column published_on_attribute_name, :timestamp
        end
        published_columns.each do |published_column|
          connection.add_column published_version_table_name, published_column.name, published_column.type,
                                     :limit     => published_column.limit,
                                     :scale     => published_column.scale,
                                     :precision => published_column.precision
          end
      end

      def drop_published_versions_table
        connection.drop_table(published_version_table_name)
      end

      const_set(published_version_class_name, Class.new(::ActiveRecord::Base)).class_eval do

        named_scope :latest_published, lambda { |primary_key_value|
          { :conditions => ["#{primary_key_attribute_name} = ? AND #{published_flag_attribute_name} = true", primary_key_value] }
        }

        named_scope :version, lambda { |primary_key_value, version_number|
          { :conditions => ["#{primary_key_attribute_name} = ? AND #{version_attribute_name} = ?", primary_key_value, version_number] }
        }

        cattr_accessor :published_flag_attribute_name
        cattr_accessor :metainformation_attributes

        def initialize(attributes)
          super
          self.latest = true
          self.published_on = Time.now
          attributes.each do |key, value|
            self[key] = value
            self.class.attr_readonly(key)
          end
        end

        def take_down!
          update_attribute(published_flag_attribute_name, false)
        end

        def published_attributes
          attributes.reject{|key|
            metainformation_attributes.include?(key)
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
        const_get published_version_class_name
      end

      published_version_class.published_flag_attribute_name = published_flag_attribute_name
      published_version_class.metainformation_attributes = published_version_metainformation_attributes

      include Previewify::Methods

    end

  end
end


ActiveRecord::Base.extend Previewify::ActiveRecord

#require 'previewify/controller'
#require 'previewify/activerecord'

#if defined? Rails
  # include stuff?
#end
