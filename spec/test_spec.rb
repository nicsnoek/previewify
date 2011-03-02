require File.expand_path('spec_helper', File.dirname(__FILE__))
require 'active_record'
require 'previewify'

ActiveRecord::Base.configurations = YAML::load(IO.read(File.expand_path('db/database.yml', File.dirname(__FILE__))))
ActiveRecord::Base.establish_connection('test')

require 'db/schema'

include Previewify::Control


describe 'Previewify' do


  class TestModel < ActiveRecord::Base

    previewify

    def some_method_for_both(some_value)
      @some_value = some_value
    end

    def another_method_for_both
      @some_value
    end

  end

  def previewified_with_defaults
    @test_model_class = TestModel
    @published_test_model_table = PublishedTestModelTable.new(@test_model_class, 'test_model_published_versions')
  end


  it "xxx" do
    @model           = TestModel.create!(:name => 'Original Name', :number => 5, :content => 'At least a litre', :float => 5.6, :active => false)
    @published_model = @model.publish!
    show_preview(false)
    model = TestModel.create!(:name => 'My Name', :number => 5, :content => 'At least a litre', :float => 5.6, :active => false)
    lambda {
      TestModel.find(model.id)
    }.should raise_error ActiveRecord::RecordNotFound
  end



  class PublishedTestModelTable

    def initialize(model_class, published_versions_table_name)
      @model_class = model_class
      @published_versions_table_name = published_versions_table_name
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

    def column_type(name)
      @model_class.columns_hash[name].type
    end

  end
end