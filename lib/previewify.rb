require 'active_record'
require 'active_support/core_ext/module/aliasing'

module Previewify

  module Control

    def show_preview(show_preview = true)
      Thread.current['Previewify::show_preview']  =  show_preview
    end

  end

  module Methods

    def self.included(target)

      target.class_eval do
        def self.find_published(*args)
          published_version = eval("#{self.published_class_name}.latest_published.find_by_id(*args)")
          raise ::ActiveRecord::RecordNotFound unless published_version.present?
          published_version
        end

        def self.find(*args)
          self.show_preview? ? super(*args) : self.find_published(*args)
        end

        def publish!
          latest_published = self.take_down!
          latest_published_version = latest_published.try(:version) || 0
          eval("#{self.class.published_class_name}.create(self.attributes.merge(:version => latest_published_version + 1))")
        end

        def take_down!
          p "Taking down live version with id #{id}"
          eval("#{self.class.published_class_name}.take_down(id)")
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

      # Create the dynamic versioned model
      #

      def published_version_table_name
        "#{self.table_name.singularize}_published_versions"
      end

      def published_class_name
        "PublishedVersion"
      end

      const_set(published_class_name, Class.new(::ActiveRecord::Base)).class_eval do

        named_scope :latest_published, :conditions => ['latest = true']

        def initialize(attributes)
          super
          self.latest = true
          attributes.each do |key, value|
            self[key] = value
          end
        end

        def self.take_down(id_to_take_down)
          #Change this to bulk update XXX set latest = false where id = id_to_take_down
          take_down_candidate = self.latest_published.find_by_id(id_to_take_down)
          p "To take down: #{take_down_candidate.inspect}"
          take_down_candidate.try(:update_attribute, :latest, false)
          take_down_candidate
        end

      end

      def create_published_versions_table
        self.connection.create_table(published_version_table_name, :primary_key => 'published_id') do |t|
          t.column 'version', :integer
          t.column 'latest', :boolean
        end
        self.published_columns.each do |col|
          self.connection.add_column published_version_table_name, col.name, col.type,
                                     :limit     => col.limit,
                                     :scale     => col.scale,
                                     :precision => col.precision
          end
      end

      def published_columns
        self.columns
      end

      def drop_published_versions_table
        self.connection.drop_table(published_version_table_name)
      end

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
