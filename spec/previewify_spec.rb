require File.expand_path('spec_helper', File.dirname(__FILE__))
require 'active_record'
require 'previewify'

ActiveRecord::Base.configurations = YAML::load(IO.read(File.expand_path('db/database.yml', File.dirname(__FILE__))))
ActiveRecord::Base.establish_connection('test')

require 'db/schema'


describe 'Previewify' do


  context "with previewified class" do

    class TestModel < ActiveRecord::Base
      previewify

    end

    describe ".create_published_versions_table" do

      it "creates published version table if it does not exist" do
        PublishedTestModelTable.drop
        PublishedTestModelTable.should_not be_in_existence
        TestModel.create_published_versions_table
        PublishedTestModelTable.should be_in_existence
      end

      context "creates a published version table that" do

        before :all do
          PublishedTestModelTable.create
        end

        it "has an integer version column by default" do
          PublishedTestModelTable.should have_column("version", :integer)
        end

        it "has all columns that the draft version has by default" do
          TestModel.columns.each do |column|
            PublishedTestModelTable.should have_column(column.name)
            PublishedTestModelTable.column_type(column.name).should == column.type

          end
        end


      end
    end

    describe ".drop_published_versions_table" do

      it "drops published version table if it exists" do
        PublishedTestModelTable.create
        PublishedTestModelTable.should be_in_existence
        TestModel.drop_published_versions_table
        PublishedTestModelTable.should_not be_in_existence
      end
    end
  end

  class PublishedTestModelTable

    PUBLISHED_TABLE_NAME = 'test_models_published_versions'

    def self.in_existence?
      TestModel.connection.tables.include?(PUBLISHED_TABLE_NAME)
    end

    def self.drop
      TestModel.connection.execute("drop table #{PUBLISHED_TABLE_NAME};") if in_existence?
    end

    def self.create
      TestModel.create_published_versions_table if !in_existence?
    end

    def self.has_column?(name, type = nil)
      TestModel.connection.column_exists?(PUBLISHED_TABLE_NAME, name, type)
    end

    def self.column_type(name)
      TestModel.columns_hash[name].type
    end

  end
end
