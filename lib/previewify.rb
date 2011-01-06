require 'active_record'

module ActiveRecord
  module Previewify

    def previewify(options = {})
      'Consider youself previewified'
    end

    def create_published_versions_table
      self.connection.create_table("#{self.table_name}_published_versions") do |t|
              t.column 'id', :integer
              t.column 'version', :integer
      end
    end


  end
end

ActiveRecord::Base.extend ActiveRecord::Previewify

#require 'previewify/controller'
#require 'previewify/activerecord'

#if defined? Rails
  # include stuff?
#end
