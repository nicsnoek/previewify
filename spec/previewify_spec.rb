require File.expand_path('spec_helper', File.dirname(__FILE__))
require 'active_record'
require 'previewify'
require 'timecop'
require 'logger'

ActiveRecord::Base.configurations = YAML::load(IO.read(File.expand_path('db/database.yml', File.dirname(__FILE__))))
ActiveRecord::Base.establish_connection('test')

ActiveRecord::Base.logger       = Logger.new(STDOUT)
ActiveRecord::Base.logger.level = Logger::DEBUG

require 'db/schema'

include Previewify::Control


describe 'Previewify' do


  class TestModel < ActiveRecord::Base
    previewify
  end

  class OtherPublishedClassNameTestModel < ActiveRecord::Base
    previewify :published_version_class_name => 'PublishedModel'
  end

  class OtherPublishedFlagTestModel < ActiveRecord::Base
    previewify :published_flag_attribute_name => 'currently_published'
  end

  class ExtraColumnsTestModel < ActiveRecord::Base
    previewify :preview_only_attributes => [:extra_content, :more_extra_content]
  end

  def default_previewified
    @test_model_class           = TestModel
    @published_test_model_table = PublishedTestModelTable.new(@test_model_class, 'test_model_published_versions')
  end

  def previewified_with_other_published_flag
    @test_model_class           = OtherPublishedFlagTestModel
    @published_test_model_table = PublishedTestModelTable.new(@test_model_class, 'other_published_flag_test_model_published_versions')
  end

  def previewified_with_preview_only_content
    @test_model_class           = ExtraColumnsTestModel
    @published_test_model_table = PublishedTestModelTable.new(@test_model_class, 'extra_columns_test_model_published_versions')
  end

  def previewified_with_other_published_class_name
    @test_model_class           = OtherPublishedClassNameTestModel
    @published_test_model_table = PublishedTestModelTable.new(@test_model_class, 'other_published_class_name_test_model_published_models')
  end

  it "preview only columns are not available on published object" do
    previewified_with_preview_only_content
    @published_test_model_table.create
    model           = @test_model_class.create!(
        :name               => 'Original Name',
        :number             => 5,
        :content            => 'At least a litre',
        :extra_content      => 'And another litre',
        :more_extra_content => 'And one little wafer',
        :float              => 5.6,
        :active             => false)
    published_model = model.publish!


    lambda {
      published_model.extra_content
    }.should raise_error NoMethodError

    lambda {
      published_model.more_extra_content
    }.should raise_error NoMethodError
  end

  ["default_previewified", "previewified_with_other_published_flag", "previewified_with_preview_only_content", "previewified_with_other_published_class_name"].each do |previewified_type|
    #[].each do |previewified_type|
    context "behaviour for #{previewified_type}" do


      before :all do
        eval(previewified_type)
      end


      describe ".create_published_versions_table" do

        it "creates published version table if it does not exist" do
          @published_test_model_table.drop
          @published_test_model_table.should_not be_in_existence
          @test_model_class.create_published_versions_table
          @published_test_model_table.should be_in_existence
        end

        context "creates a published version table that" do

          before :all do
            @published_test_model_table.create
          end

          it "has an integer version column by default" do
            @published_test_model_table.should have_column("version", :integer)
          end

          it "has an published_id column by default" do
            @published_test_model_table.should have_column("published_id", :integer)
          end

          it "has all published columns of the draft version" do
            @test_model_class.columns.each do |column|
              if is_published? column
                @published_test_model_table.should have_column(column.name)
                @published_test_model_table.column_type(column.name).should == column.type
              end
            end
          end


        end
      end

      describe ".drop_published_versions_table" do

        it "drops published version table if it exists" do
          @published_test_model_table.create
          @published_test_model_table.should be_in_existence
          @test_model_class.drop_published_versions_table
          @published_test_model_table.should_not be_in_existence
        end
      end

      context "when the published versions table has been created" do

        before :all do
          @published_test_model_table.create
        end


        context "a published object" do

          before :each do
            @model           = @test_model_class.create!(:name => 'Original Name', :number => 5, :content => 'At least a litre', :float => 5.6, :active => false)
            @published_model = @model.publish!
          end

          it "can not have its original attributes modified" do
            @published_model.name   = 'Other Name'
            @published_model.number = 42
            @published_model.save!

            show_preview(false)
            retrieved_published_model = @test_model_class.find(@model.id)
            retrieved_published_model.name.should == 'Original Name'
            retrieved_published_model.number.should == 5
          end

          it "can not have its version attribute modified" do
            original_version_number  = @published_model.version
            @published_model.version = 10
            @published_model.save!

            show_preview(false)
            retrieved_published_model = @test_model_class.find(@model.id)
            retrieved_published_model.version.should == original_version_number
          end

          it "#take_down! makes published version inaccessible" do
            @published_model.take_down!

            show_preview(false)
            lambda {
              @test_model_class.find(@model.id)
            }.should raise_error ActiveRecord::RecordNotFound
          end

          it ".specific_version_by_primary_key returns specified version" do
            @published_model.class.specific_version_by_primary_key(@model.id, 1).should == @published_model
          end

          it "#published_attributes only includes attributes published from preview object" do
            published_attributes = @published_model.published_attributes
            published_attributes.should_not have_key('published_id')
          end

        end

        describe "#publish!" do

          before :all do
            @published_test_model_table.create
          end

          it "creates a published version of the object with same attributes as preview object and initial version" do
            model           = @test_model_class.create!(:name => 'My Name', :number => 5, :content => 'At least a litre', :float => 5.6, :active => false)
            published_model = model.publish!
            published_model.version.should == 1
            model.attribute_names.each do |attribute_name|
              published_model.send(attribute_name).should == model.send(attribute_name) if is_published?(attribute_name)
            end
          end

          it "creates a published version of the object with same attributes as preview object and increased version number" do
            model = @test_model_class.create!(:name => 'My Name', :number => 5, :content => 'At least a litre', :float => 5.6, :active => false)
            model.publish!

            model.update_attributes(:name => 'Other Name', :number => 55)
            published_model = model.publish!

            published_model.version.should == 2
            model.attribute_names.each do |attribute_name|
              published_model.send(attribute_name).should == model.send(attribute_name) if is_published?(attribute_name)
            end
          end

        end

        describe "#take_down" do
          before :all do
            @published_test_model_table.create
          end

          it "returns nil but does not raise exception if object is not published" do
            model = @test_model_class.create!(:name => 'My Name', :number => 5, :content => 'At least a litre', :float => 5.6, :active => false)
            model.take_down!.should be_nil
          end

          it "returns taken down object and resets 'latest' flag on currently published object" do
            model = @test_model_class.create!(:name => 'My Name', :number => 5, :content => 'At least a litre', :float => 5.6, :active => false)
            model.publish!
            taken_down = model.take_down!
            taken_down.latest.should be_false
          end

        end

        describe '#published_on' do

          before :each do
            @published_test_model_table.create
            @model = @test_model_class.create!(:name => 'Original Name', :number => 5, :content => 'At least a litre', :float => 5.6, :active => false)
          end

          context "when unpublished" do

            describe "the preview object" do
              it "returns nil" do
                @model.published_on.should be_nil
              end
            end

          end

          context "when published" do

            before :each do
              Timecop.freeze(Time.now.to_s) do
                @published_on    = Time.now
                @published_model = @model.publish!
              end
            end

            describe "the published object" do
              it "returns the timestamp of when the object was published" do
                @published_model.published_on.should == @published_on
              end
            end

            describe "the preview object" do
              it "returns the timestamp of when the object was published" do
                @model.published_on.should == @published_on
              end
            end

            context "and then taken down" do

              before :each do
                @model.take_down!
              end

              it "returns nil" do
                @model.published_on.should be_nil
              end
            end

          end

        end

        describe '#has_unpublished_changes?' do
          before :each do
            @model = @test_model_class.create!(:name => 'Original Name', :number => 5, :content => 'At least a litre', :float => 5.6, :active => false)
          end

          it "is false when unpublished" do
            @model.has_unpublished_changes?.should be_false
          end

          it "is false when published without changes" do
            @model.publish!
            @model.has_unpublished_changes?.should be_false
          end

          it "is true when changes have been made without publishing" do
            @model.publish!
            @model.name = 'Modified name'
            @model.has_unpublished_changes?.should be_true
          end

          it "is true when changes have been saved without publishing" do
            @model.publish!
            @model.name = 'Modified name'
            @model.save
            @model.has_unpublished_changes?.should be_true
          end

        end

        describe ".find" do

          context "in preview mode" do

            before :each do
              show_preview(true)
            end

            it "finds preview version" do
              model = @test_model_class.create!(:name => 'My Name', :number => 5, :content => 'At least a litre', :float => 5.6, :active => false)
              @test_model_class.find(model.id).should == model
            end
          end

          context "in live mode" do

            before :each do
              show_preview(false)
            end


            it "does not find preview version" do
              model = @test_model_class.create!(:name => 'My Name', :number => 5, :content => 'At least a litre', :float => 5.6, :active => false)
              lambda {
                @test_model_class.find(model.id)
              }.should raise_error ActiveRecord::RecordNotFound
            end

            it "finds published version with matching id" do
              model = @test_model_class.create!(:name => 'My Name', :number => 5, :content => 'At least a litre', :float => 5.6, :active => false)
              model.publish!
              published_model = @test_model_class.find(model.id)
              published_model.id.should == model.id
            end

            it "does not find preview version or published version when item is taken down" do
              model = @test_model_class.create!(:name => 'My Name', :number => 5, :content => 'At least a litre', :float => 5.6, :active => false)
              model.publish!
              model.take_down!
              lambda {
                @test_model_class.find(model.id)
              }.should raise_error ActiveRecord::RecordNotFound
            end

          end


        end

        describe "#revert_to_version" do

          it "reverts preview to specified version" do
            model = @test_model_class.create!(:name => 'My Name', :number => 10, :content => 'At least a litre', :float => 5.6, :active => false)
            model.publish! #version 1
            model.number = 20
            model.publish! #version 2
            model.revert_to_version!(1)
            model.number.should == 10
            model.revert_to_version!(2)
            model.number.should == 20
          end

        end
      end
    end
  end

  def is_published?(name)
    @test_model_class.previewify_options.published_columns.include? name
  end


  class PublishedTestModelTable

    def initialize(model_class, published_versions_table_name)
      @model_class                   = model_class
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
