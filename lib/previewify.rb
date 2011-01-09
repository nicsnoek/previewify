require 'active_record'

module ActiveRecord
  module Previewify

    def previewify(options = {})
      'Consider youself previewified'
    end

    def published_version_table_name
      "#{self.table_name}_published_versions"
    end

    def create_published_versions_table
      self.connection.create_table(published_version_table_name) do |t|
        t.column 'id', :integer
        t.column 'version', :integer
      end
      self.published_columns.each do |col|
        self.connection.add_column published_version_table_name, col.name, col.type,
                                   :limit     => col.limit,
                                   :scale     => col.scale,
                                   :precision => col.precision
        end
    end

    def published_columns
      self.columns.reject {|col| col.primary }
    end

    def drop_published_versions_table
      self.connection.drop_table(published_version_table_name)
    end

  end
end

ActiveRecord::Base.extend ActiveRecord::Previewify

#require 'previewify/controller'
#require 'previewify/activerecord'

#if defined? Rails
  # include stuff?
#end
