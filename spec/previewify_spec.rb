require File.expand_path('spec_helper', File.dirname(__FILE__))
require 'active_record'
require 'previewify'
require 'timecop'
require 'logger'

ActiveRecord::Base.configurations = YAML::load(IO.read(File.expand_path('db/database.yml', File.dirname(__FILE__))))
ActiveRecord::Base.establish_connection('test')

ActiveRecord::Base.logger       = Logger.new(STDOUT)
ActiveRecord::Base.logger.level = Logger::DEBUG

require 'db/drop_published_versions'
require 'db/schema'


describe 'Previewify' do

  def show_preview preview_mode
    Thread.current['Previewify::show_preview'] = preview_mode
  end


  class TestModel < ActiveRecord::Base

    previewify

    def some_method_for_both(some_value)
      @some_value = some_value
    end

    def another_method_for_both
      @some_value
    end

  end

  class TestModelWithValidation < ActiveRecord::Base

    validates_presence_of :name
    validates_presence_of :extra_content

    previewify :preview_only_attributes => [:extra_content]

  end

  class OtherPrimaryKeyTestModel < ActiveRecord::Base
    set_primary_key 'other_pk'
    previewify
  end

  class OtherPublishedClassNameTestModel < ActiveRecord::Base
    previewify :published_version_class_name => 'PublishedModel'
  end

  class OtherPublishedFlagTestModel < ActiveRecord::Base
    previewify :published_flag_attribute_name => 'currently_published'
  end

  class ExtraPreviewColumnsTestModel < ActiveRecord::Base
    previewify :preview_only_attributes => [:extra_content, :more_extra_content]
  end

  class ExtraPreviewMethodTestModel < ActiveRecord::Base

    def some_method_for_preview(some_value)
      @some_value = some_value
    end

    def another_method_for_preview
      @some_value
    end

    previewify :preview_only_methods => [:some_method_for_preview, :another_method_for_preview]
  end

  class ExtraPublishedMethodTestModel < ActiveRecord::Base

    def some_method_for_published(some_value)
      @some_value = some_value
    end

    def another_method_for_published
      @some_value
    end

    previewify :published_only_methods => [:some_method_for_published, :another_method_for_published]

  end

  class OtherPublishedVersionPkTestModel < ActiveRecord::Base
    previewify :published_version_primary_key_name => 'zippy_id'
  end

  def default_previewified
    @test_model_class           = TestModel
    @published_test_model_table = PublishedTestModelTable.new(@test_model_class, 'test_model_published_versions')
  end

  def default_previewified_with_validation
    @test_model_class           = TestModelWithValidation
    @published_test_model_table = PublishedTestModelTable.new(@test_model_class, 'test_model_with_validation_published_versions')
  end

  def previewified_with_other_primary_key
    @test_model_class           = OtherPrimaryKeyTestModel
    @published_test_model_table = PublishedTestModelTable.new(@test_model_class, 'other_primary_key_test_model_published_versions')
  end

  def previewified_with_other_published_flag
    @test_model_class           = OtherPublishedFlagTestModel
    @published_test_model_table = PublishedTestModelTable.new(@test_model_class, 'other_published_flag_test_model_published_versions')
  end

  def previewified_with_preview_only_content
    @test_model_class           = ExtraPreviewColumnsTestModel
    @published_test_model_table = PublishedTestModelTable.new(@test_model_class, 'extra_preview_columns_test_model_published_versions')
  end

  def previewified_with_other_published_class_name
    @test_model_class           = OtherPublishedClassNameTestModel
    @published_test_model_table = PublishedTestModelTable.new(@test_model_class, 'other_published_class_name_test_model_published_models')
  end

  def extra_preview_method_previewified
    @test_model_class           = ExtraPreviewMethodTestModel
    @published_test_model_table = PublishedTestModelTable.new(@test_model_class, 'extra_preview_method_test_model_published_versions')
  end

  def extra_published_method_previewified
    @test_model_class           = ExtraPublishedMethodTestModel
    @published_test_model_table = PublishedTestModelTable.new(@test_model_class, 'extra_published_method_test_model_published_versions')
  end

  def other_published_version_pk_previewified
    @test_model_class           = OtherPublishedVersionPkTestModel
    @published_test_model_table = PublishedTestModelTable.new(@test_model_class, 'other_published_version_pk_test_model_published_versions', 'zippy_id')
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

  describe "method that should be available on draft and preview" do

    before :each do
      default_previewified
      @published_test_model_table.create
      @model           = @test_model_class.create!(
          :name               => 'Original Name',
          :number             => 5,
          :content            => 'At least a litre',
          :float              => 5.6,
          :active             => false)
      @published_model = @model.publish!
    end

    it "is available on preview version" do
      @model.should respond_to :some_method_for_both
      @model.should respond_to :another_method_for_both
      @model.some_method_for_both("test value")
      @model.another_method_for_both.should == "test value"
    end

    it "is available on published version" do
      @published_model.should respond_to :some_method_for_both
      @published_model.should respond_to :another_method_for_both
      @published_model.some_method_for_both("test value")
      @published_model.another_method_for_both.should == "test value"
    end
  end

  describe "method that should be only available on preview" do

    before :each do
      extra_preview_method_previewified
      @published_test_model_table.create
      @model           = @test_model_class.create!(
          :name               => 'Original Name',
          :number             => 5,
          :content            => 'At least a litre',
          :float              => 5.6,
          :active             => false)
      @published_model = @model.publish!
    end

    it "is only available on preview version" do
      @model.should respond_to :some_method_for_preview
      @model.should respond_to :another_method_for_preview
      @model.some_method_for_preview("a test value")
      @model.another_method_for_preview.should == "a test value"
    end

    it "is not available on published version" do
      @published_model.should_not respond_to :some_method_for_preview
      @published_model.should_not respond_to :another_method_for_preview
    end
  end

  describe "method that should be only available on published" do

    before :each do
      extra_published_method_previewified
      @published_test_model_table.create
      @model           = @test_model_class.create!(
          :name               => 'Original Name',
          :number             => 5,
          :content            => 'At least a litre',
          :float              => 5.6,
          :active             => false)
      @published_model = @model.publish!
    end

    it "is not available on preview version" do
      @model.should_not respond_to :some_method_for_published
      @model.should_not respond_to :another_method_for_published
    end

    it "is only available on published version" do
      @published_model.should respond_to :some_method_for_published
      @published_model.should respond_to :another_method_for_published
      @published_model.some_method_for_published("test argument value")
      @published_model.another_method_for_published.should == "test argument value"
    end
  end

  context "with a validation error" do
    before :each do
      default_previewified_with_validation
      @published_test_model_table.create
      @model           = @test_model_class.create!(
          :name               => 'Original Name',
          :number             => 5,
          :content            => 'At least a litre',
          :extra_content      => 'And another litre',
          :float              => 5.6,
          :active             => false)
    end
    describe "#publish!" do
      
      it "should raise RecordNotPublished if the error is on a published attribute" do
        @model.name = nil
        lambda {
          @model.publish!
        }.should raise_error(::Previewify::ActiveRecord::RecordNotPublished)
      end

      it "should raise RecordNotPublished if the error is on a unpublished attribute" do
        @model.extra_content = nil
        @model.name = nil
        lambda {
          @model.publish!
        }.should raise_error(::Previewify::ActiveRecord::RecordNotPublished)
      end
    end
  end

  context "with other published_version_primary_key_name" do
    it "should have configured primary key on published version" do
      other_published_version_pk_previewified
      @published_test_model_table.create
      @model           = @test_model_class.create!(
          :name               => 'Original Name',
          :number             => 5,
          :content            => 'At least a litre',
          :float              => 5.6,
          :active             => false)
      published_version = @model.publish!
      published_version.zippy_id.should == 1
    end
  end

  ["default_previewified",
   "previewified_with_other_primary_key",
   "previewified_with_other_published_flag",
   "previewified_with_preview_only_content",
   "previewified_with_other_published_class_name",
   "extra_preview_method_previewified",
   "extra_published_method_previewified",
   "other_published_version_pk_previewified"
  ].each do |previewified_type|
    context "behaviour for #{previewified_type}" do


      before :all do
        eval(previewified_type)
      end
#    context "behaviour for default_previewified" do
#
#
#      before :all do
#        eval('previewified_with_other_primary_key')
#      end

      context "an unsaved model" do
        it "should " do
          model           = @test_model_class.new(
              :name               => 'Original Name',
              :number             => 5,
              :content            => 'At least a litre',
              :float              => 5.6,
              :active             => false)
          lambda {
            model.publish!
          }.should raise_error(::Previewify::ActiveRecord::RecordNotPublished)
        end
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

          it "has an integer version_number column by default" do
            @published_test_model_table.should have_column("version_number", :integer)
          end

          it "has an primary_key column by default" do
            @published_test_model_table.should have_published_primary_key_column(:integer)
          end

          it "has all published columns of the draft version" do
            @test_model_class.columns.each do |column|
              if is_published? column.name
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

      context "when the published versions table has been created," do

        before :all do
          @published_test_model_table.create
        end

        context "a published object" do

          before :each do
            @model           = @test_model_class.create!(:name => 'Original Name', :number => 5, :content => 'At least a litre', :float => 5.6, :active => false)
            @published_model_v1 = @model.publish!
            @published_model_v2 = @model.publish!
            @published_model_v2.take_down!
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

          it "can not have its version_number attribute modified" do
            original_version_number  = @published_model.version_number
            @published_model.version_number = 10
            @published_model.save!

            show_preview(false)
            retrieved_published_model = @test_model_class.find(@model.id)
            retrieved_published_model.version_number.should == original_version_number
          end

          it "#take_down! makes published version inaccessible" do
            @published_model.take_down!

            show_preview(false)
            lambda {
              @test_model_class.find(@model.id)
            }.should raise_error ActiveRecord::RecordNotFound
          end

          it ".specific_version_by_primary_key returns specified version" do
            @published_model.class.specific_version_by_primary_key(@model.id, 1).should == @published_model_v1
          end

          it ".all_versions_by_primary_key returns all versions" do
            @published_model.class.all_versions_by_primary_key(@model.id).should == [@published_model_v1, @published_model_v2, @published_model]
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
            published_model.version_number.should == 1
            model.attribute_names.each do |attribute_name|
              published_model.send(attribute_name).should == model.send(attribute_name) if is_published?(attribute_name)
            end
          end

          it "creates a published version of the object with same attributes as preview object and increased version number" do
            model = @test_model_class.create!(:name => 'My Name', :number => 5, :content => 'At least a litre', :float => 5.6, :active => false)
            model.publish!

            model.update_attributes(:name => 'Other Name', :number => 55)
            published_model = model.publish!

            published_model.version_number.should == 2
            model.attribute_names.each do |attribute_name|
              published_model.send(attribute_name).should == model.send(attribute_name) if is_published?(attribute_name)
            end
          end

        end

        describe "#take_down" do
          before :all do
            @published_test_model_table.create
          end

          it "does nothing on unpublished object" do
            model = @test_model_class.create!(:name => 'My Name', :number => 5, :content => 'At least a litre', :float => 5.6, :active => false)
            model.published?.should be_false
            model.take_down!
            model.published?.should be_false
          end

          it "causes currently published object to become unpublished" do
            model = @test_model_class.create!(:name => 'My Name', :number => 5, :content => 'At least a litre', :float => 5.6, :active => false)
            model.publish!
            model.published?.should be_true
            model.take_down!
            model.published?.should be_false
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

        describe '#published?' do
          before :each do
            @model = @test_model_class.create!(:name => 'Original Name', :number => 5, :content => 'At least a litre', :float => 5.6, :active => false)
          end

          it "false when unpublished" do
            @model.published?.should be_false
          end

          it "true when published without changes" do
            published_model = @model.publish!
            @model.published?.should be_true
            published_model.published?.should be_true
          end

          it "is true for a published version that has been found by a finder" do
            published_model = @model.publish!
            show_preview(false)
            retrieved_published_model = @test_model_class.find(@model.id)
            retrieved_published_model.published?.should be_true
          end

          it "true when changes have been saved without publishing" do
            published_model = @model.publish!
            @model.name = 'Modified name'
            @model.save
            @model.published?.should be_true
            published_model.published?.should be_true
          end

          it "false when taken down after publishing" do
            published_model = @model.publish!
            @model.take_down!
            @model.published?.should be_false
          end

        end

        describe '#version_number' do
          before :each do
            @model = @test_model_class.create!(:name => 'Original Name', :number => 5, :content => 'At least a litre', :float => 5.6, :active => false)
          end

          it "nil when unpublished" do
            @model.version_number.should be_nil
          end

          it "nil when taken down" do
            @model.publish!
            @model.take_down!
            @model.version_number.should be_nil
          end

          it "reflects the latest published version_number" do
            published_version_number1 = @model.publish!
            @model.version_number.should == 1
            published_version_number1.version_number.should == 1
            published_version_number2 = @model.publish!
            @model.version_number.should == 2
            published_version_number2.version_number.should == 2
          end

        end

        describe "#id" do
          it "should be the same on preview and all published versions" do
            model = @test_model_class.create!(:name => 'Original Name', :number => 5, :content => 'At least a litre', :float => 5.6, :active => false)
            published_model1 = model.publish!
            published_model2 = model.publish!
            #Note: This shows that there is something suspect about the published model: All versions have the same id! This is because they
            #should all be able to masquerade as the preview version. They all have a different "published_id"
            published_model1.id.should == model.id
            published_model2.id.should == model.id
          end

          it "should be the same on preview and all published versions even if take down has a problem" do
            begin
            model = @test_model_class.create!(:name => 'Original Name', :number => 5, :content => 'At least a litre', :float => 5.6, :active => false)
            published_model = model.publish!
            published_model.stub(:create_or_update).and_raise(RuntimeError)
            published_model.take_down!
            ::RSpec::Expectations.fail_with("Should have thrown an exception")
            rescue RuntimeError => e
              published_model.id.should == model.id
            end
          end
        end

        describe 'on preview model' do
          describe '#has_unpublished_changes?' do
            before :each do
              @model = @test_model_class.create!(:name => 'Original Name', :number => 5, :content => 'At least a litre', :float => 5.6, :active => false)
            end

            it "false when unpublished" do
              @model.has_unpublished_changes?.should be_false
            end

            it "false when published without changes" do
              @model.publish!
              @model.has_unpublished_changes?.should be_false
            end

            it "true when changes have been made without publishing" do
              @model.publish!
              @model.name = 'Modified name'
              @model.has_unpublished_changes?.should be_true
            end

            it "true when changes have been saved without publishing" do
              @model.publish!
              @model.name = 'Modified name'
              @model.save
              @model.has_unpublished_changes?.should be_true
            end

            it "false when taken down after publishing" do
              @model.publish!
              @model.take_down!
              @model.has_unpublished_changes?.should be_false
            end

          end
        end

        describe 'on published model' do
          describe '#has_unpublished_changes?' do
            before :each do
              @model = @test_model_class.create!(:name => 'Original Name', :number => 5, :content => 'At least a litre', :float => 5.6, :active => false)
            end

            it "false when unpublished" do
              @model.has_unpublished_changes?.should be_false
            end

            it "false when published without changes" do
              published_model = @model.publish!
              published_model.has_unpublished_changes?.should be_false
            end

            it "false when changes have been made without publishing" do
              published_model = @model.publish!
              @model.name = 'Modified name'
              published_model.has_unpublished_changes?.should be_false
            end

            it "false when changes have been saved without publishing" do
              published_model = @model.publish!
              @model.name = 'Modified name'
              @model.save
              published_model.has_unpublished_changes?.should be_false
            end

            it "false when taken down after publishing" do
              published_model = @model.publish!
              @model.take_down!
              published_model.has_unpublished_changes?.should be_false
            end

          end
        end

        describe ".find" do

          context "in preview mode" do

            before :each do
              show_preview(true)
            end

            it "finds preview versions by id" do
              model1 = @test_model_class.create!(:name => 'My Name1', :number => 5, :content => 'At least a cup', :float => 5.6, :active => false)
              model2 = @test_model_class.create!(:name => 'My Name2', :number => 5, :content => 'At least a cup', :float => 5.6, :active => false)
              @test_model_class.find(model1.id).should == model1
              @test_model_class.find(model1.id, model2.id).should == [model1, model2]
            end

            it "finds preview versions by condition" do
              model1 = @test_model_class.create!(:name => 'My Name1', :number => 5, :content => 'At least two cups', :float => 5.6, :active => false)
              model2 = @test_model_class.create!(:name => 'My Name2', :number => 5, :content => 'At least two cups', :float => 5.6, :active => false)
              @test_model_class.find(:first, :conditions => {:content => 'At least two cups'}).should == model1
              @test_model_class.find(:all, :conditions => {:content => 'At least two cups'}).should == [model1, model2]
              @test_model_class.find(:last, :conditions => {:content => 'At least two cups'}).should == model2
            end

          end

          context "in live mode" do

            before :each do
              show_preview(false)
            end


            it "does not find preview only versions by id" do
              model1 = @test_model_class.create!(:name => 'My Name', :number => 5, :content => 'At least a litre', :float => 5.6, :active => false)
              model2 = @test_model_class.create!(:name => 'My Name', :number => 5, :content => 'At least a litre', :float => 5.6, :active => false)

              lambda {
                @test_model_class.find(model1.id)
              }.should raise_error ActiveRecord::RecordNotFound

              lambda {
                @test_model_class.find(model1.id, model2.id)
              }.should raise_error ActiveRecord::RecordNotFound
            end

            it "does not find preview only versions by condition" do
              model = @test_model_class.create!(:name => 'My Name', :number => 5, :content => 'At least a centi-litre', :float => 5.6, :active => false)
              @test_model_class.find(:first, :conditions => {:content => 'At least a centi-litre'}).should be_nil
              @test_model_class.find(:all, :conditions => {:content => 'At least a centi-litre'}).should == []
              @test_model_class.find(:last, :conditions => {:content => 'At least a centi-litre'}).should be_nil
              @test_model_class.all(:conditions => {:content => 'At least a centi-litre'}).should == []
            end

            it "finds published versions by id" do
              model1 = @test_model_class.create!(:name => 'My Name', :number => 5, :content => 'At least a litre', :float => 5.6, :active => false)
              model2 = @test_model_class.create!(:name => 'My Name', :number => 5, :content => 'At least a litre', :float => 5.6, :active => false)
              model1.publish!
              model2.publish!
              @test_model_class.find(model1.id).id.should == model1.id
              published_models = @test_model_class.find(model1.id, model2.id)
              published_models[0].id.should == model1.id
              published_models[1].id.should == model2.id
            end

            it "finds published versions by condition" do
              model1 = @test_model_class.create!(:name => 'My Name', :number => 5, :content => 'At least a femto-litre', :float => 5.6, :active => false)
              model2 = @test_model_class.create!(:name => 'My Name', :number => 5, :content => 'At least a femto-litre', :float => 5.6, :active => false)
              model1.publish!
              model2.publish!
              @test_model_class.find(:first, :conditions => {:content => 'At least a femto-litre'}).id.should == model1.id
              @test_model_class.find(:last, :conditions => {:content => 'At least a femto-litre'}).id.should == model2.id
              published_models = @test_model_class.find(:all, :conditions => {:content => 'At least a femto-litre'})
              published_models[0].id.should == model1.id
              published_models[1].id.should == model2.id
            end

            it "does not find any versions by id when any items are taken down" do
              model1 = @test_model_class.create!(:name => 'My Name', :number => 5, :content => 'At least a litre', :float => 5.6, :active => false)
              model2 = @test_model_class.create!(:name => 'My Name', :number => 5, :content => 'At least a litre', :float => 5.6, :active => false)
              model1.publish!
              model1.take_down!
              model2.publish!

              lambda {
                @test_model_class.find(model1.id)
              }.should raise_error ActiveRecord::RecordNotFound

              lambda {
                @test_model_class.find(model1.id, model2.id)
              }.should raise_error ActiveRecord::RecordNotFound
            end

            it "does not find any versions by condition when items are taken down" do
              model1 = @test_model_class.create!(:name => 'My Name', :number => 5, :content => 'At least a splash', :float => 5.6, :active => false)
              model2 = @test_model_class.create!(:name => 'My Name', :number => 5, :content => 'At least a splash', :float => 5.6, :active => false)
              model1.publish!
              model1.take_down!
              model2.publish!
              model2.take_down!
              @test_model_class.find(:first, :conditions => {:content => 'At least a splash'}).should be_nil
              @test_model_class.find(:all, :conditions => {:content => 'At least a splash'}).should == []
              @test_model_class.find(:last, :conditions => {:content => 'At least a splash'}).should be_nil
            end

          end


        end

        describe ".all" do

          context "in preview mode" do

            before :each do
              show_preview(true)
              @test_model_class.delete_all
            end

            it "finds all previews" do
              model1 = @test_model_class.create!(:name => 'My Name1', :number => 5, :content => 'At least a cup', :float => 5.6, :active => false)
              model2 = @test_model_class.create!(:name => 'My Name2', :number => 5, :content => 'At least a cup', :float => 5.6, :active => false)
              @test_model_class.all.should == [model1, model2]
            end

          end

          context "in live mode" do

            before :each do
              show_preview(false)
              @test_model_class.delete_all
              @test_model_class.published_version_class.delete_all
            end


            it "finds all published models" do
              model1 = @test_model_class.create!(:name => 'My Name1', :number => 5, :content => 'At least a cup', :float => 5.6, :active => false)
              model2 = @test_model_class.create!(:name => 'My Name2', :number => 5, :content => 'At least a cup', :float => 5.6, :active => false)
              model1_published = model1.publish!
              model2_published = model2.publish!
              @test_model_class.all.should == [model1_published, model2_published]
            end

            it "does not find unpublished models" do
              model = @test_model_class.create!(:name => 'My Name', :number => 5, :content => 'At least a centi-litre', :float => 5.6, :active => false)
              @test_model_class.all.should == []
            end

            it "does not find published models that have been taken down" do
              model = @test_model_class.create!(:name => 'My Name', :number => 5, :content => 'At least a centi-litre', :float => 5.6, :active => false)
              model.publish!
              model.take_down!
              @test_model_class.all.should == []
            end
          end
        end

        describe "dynamic finder" do

          context "in preview mode" do

            before :each do
              show_preview(true)
            end

            it "finds preview version" do
              model = @test_model_class.create!(:name => 'My Unique Name1', :number => 5, :content => 'At least a litre', :float => 5.6, :active => false)
              @test_model_class.find_by_name('My Unique Name1').should == model
            end

            it "finds preview versions" do
              model1 = @test_model_class.create!(:name => 'My Unique Name1bis', :number => 5, :content => 'At least a litre', :float => 5.6, :active => false)
              model2 = @test_model_class.create!(:name => 'My Unique Name1bis', :number => 5, :content => 'At least a litre', :float => 5.6, :active => false)
              @test_model_class.find_all_by_name('My Unique Name1bis').should == [model1, model2]
            end
          end

          context "in live mode" do

            before :each do
              show_preview(false)
            end


            it "does not find preview only version" do
              model = @test_model_class.create!(:name => 'My Unique Name2', :number => 5, :content => 'At least a litre', :float => 5.6, :active => false)
              @test_model_class.find_by_name('My Unique Name2').should be_nil
            end

            it "finds published version with matching value" do
              model = @test_model_class.create!(:name => 'My Unique Name3', :number => 5, :content => 'At least a litre', :float => 5.6, :active => false)
              model.publish!
              published_model = @test_model_class.find_by_name('My Unique Name3')
              published_model.name.should == model.name
            end

            it "finds published version with matching values" do
              model1 = @test_model_class.create!(:name => 'My Unique Name3bis', :number => 5, :content => 'At least a litre', :float => 5.6, :active => false)
              model2 = @test_model_class.create!(:name => 'My Unique Name3bis', :number => 5, :content => 'At least a litre', :float => 5.6, :active => false)
              model1.publish!
              model2.publish!
              published_models = @test_model_class.find_all_by_name('My Unique Name3bis')
              published_models.length.should == 2
            end

            it "does not find preview version or published version when item is taken down" do
              model = @test_model_class.create!(:name => 'My Unique Name4', :number => 5, :content => 'At least a litre', :float => 5.6, :active => false)
              model.publish!
              model.take_down!
              @test_model_class.find_all_by_name('My Unique Name4').should == []
              @test_model_class.find_by_name('My Unique Name4').should be_nil
            end

          end


        end

        context "with multiple versions" do

          before :each do
            @model = @test_model_class.create!(:name => 'My Name', :number => 10, :content => 'At least a litre', :float => 5.6, :active => false)
            @model.publish! #version 1
            @model.number = 20
            @model.publish! #version 2
          end

          describe "#versions" do
            it "returns all published versions" do
              versions = @model.versions
              versions.length.should == 2
              versions[0].version_number.should == 1
              versions[0].number.should == 10
              versions[1].version_number.should == 2
              versions[1].number.should == 20
            end
          end

          describe "#revert_to_version" do

            it "reverts preview to specified version" do
              @model.revert_to_version_number!(1)
              @model.number.should == 10
              @model.revert_to_version_number!(2)
              @model.number.should == 20
            end

          end


          describe "#version" do

            it "returns specified version" do
              version1 = @model.version(1)
              version1.version_number.should == 1
              version1.number.should == 10
            end
          end
        end

        describe ".to_ary" do

          # This behaviour spec is the result of a non-obvious bug where flattening an array of class objects
          # caused it to return an array with all published objects when in published mode.
          # That's what happens when you start messing with method_missing...

          context "in preview mode" do

            before :each do
              show_preview(true)
            end

            it "creates array containing class" do
              [@test_model_class].flatten.should == [@test_model_class]
            end

          end

          context "in live mode" do

            before :each do
              show_preview(false)
            end

            it "creates array containing class" do
              [@test_model_class].flatten.should == [@test_model_class]
            end
          end


        end

      end
    end
  end

end
