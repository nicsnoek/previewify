$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'rspec'
require 'previewify'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

RSpec.configure do |c|
  c.add_setting :use_transactional_fixtures, :default => true
end

class PublishedTestModelTable

  def initialize(model_class, published_versions_table_name, published_primary_key_name = 'published_id')
    @model_class                   = model_class
    @published_versions_table_name = published_versions_table_name
    @published_primary_key_name = published_primary_key_name
  end

  def in_existence?
    @model_class.connection.tables.include?(@published_versions_table_name)
  end

  def drop
    @model_class.connection.execute("drop table #{@published_versions_table_name};") if in_existence?
  end

  def create
    @model_class.create_published_versions_table if !in_existence?
  end

  def has_column?(name, type = nil)
    @model_class.connection.column_exists?(@published_versions_table_name, name, type)
  end

  def has_published_primary_key_column?(type)
    has_column?(@published_primary_key_name, type)
  end

  def column_type(name)
    @model_class.columns_hash[name].type
  end

end


def is_published_column?(name)
  @test_model_class.published_version_class.columns.include? name
end




