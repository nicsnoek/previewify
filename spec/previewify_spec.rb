require File.expand_path('spec_helper', File.dirname(__FILE__))
require 'active_record'
require 'previewify'

ActiveRecord::Base.configurations = YAML::load(IO.read(File.expand_path('db/database.yml', File.dirname(__FILE__))))
ActiveRecord::Base.establish_connection('test')

require 'db/schema'


describe 'Previewify' do


  class TestModel < ActiveRecord::Base
    previewify
  end

  def previewified_with_defaults
    @published_test_model_table = PublishedTestModelTable.new(TestModel, 'test_models_published_versions')
  end

  def previewified_with_table_name
    TestModel.previewify(:published_versions_table_name => 'live_test_models')
    @published_test_model_table = PublishedTestModelTable.new(TestModel, 'live_test_models')
  end

  ['previewified_with_defaults', 'previewified_with_table_name'].each do |config|
    context "behaviour for #{config}" do

      before :all do
        eval(config)
      end

      describe ".create_published_versions_table" do

        it "creates published version table if it does not exist" do
          @published_test_model_table.drop
          @published_test_model_table.should_not be_in_existence
          TestModel.create_published_versions_table
          @published_test_model_table.should be_in_existence
        end

        context "creates a published version table that" do

          before :all do
            @published_test_model_table.create
          end

          it "has an integer version column by default" do
            @published_test_model_table.should have_column("version", :integer)
          end

          it "has all columns that the draft version has by default" do
            TestModel.columns.each do |column|
              @published_test_model_table.should have_column(column.name)
              @published_test_model_table.column_type(column.name).should == column.type

            end
          end


        end
      end

      describe ".drop_published_versions_table" do

        it "drops published version table if it exists" do
          @published_test_model_table.create
          @published_test_model_table.should be_in_existence
          TestModel.drop_published_versions_table
          @published_test_model_table.should_not be_in_existence
        end
      end
    end
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
