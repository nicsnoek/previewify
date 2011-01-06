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


  context "with previewified class" do
    describe ".create_published_versions_table" do

      before :each do
        PublishedTestModelTable.drop
      end

      it "creates published version table if it does not exist" do
        PublishedTestModelTable.should_not be_in_existence
        TestModel.create_published_versions_table
        PublishedTestModelTable.should be_in_existence
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

  end
end
