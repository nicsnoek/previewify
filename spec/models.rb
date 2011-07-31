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
  validates_presence_of :extra_content, :if => :preview_object?

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
