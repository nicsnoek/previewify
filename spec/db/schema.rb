ActiveRecord::Schema.define :version => 0 do

  create_table :test_models, :force => true do |t|
    t.string :name
    t.integer :number
    t.text :content
    t.float :float
    t.boolean :active
  end

  create_table :other_published_class_name_test_models, :force => true do |t|
    t.string :name
    t.integer :number
    t.text :content
    t.float :float
    t.boolean :active
  end

  create_table :extra_columns_test_models, :force => true do |t|
    t.string :name
    t.integer :number
    t.text :content
    t.text :extra_content
    t.text :more_extra_content
    t.float :float
    t.boolean :active
  end

  create_table :other_published_flag_test_models, :force => true do |t|
     t.string :name
     t.integer :number
     t.text :content
     t.float :float
     t.boolean :active
     t.boolean :latest #imagine that this table already used this name...
   end
end