ActiveRecord::Schema.define :version => 0 do

   create_table :test_models, :force => true do |t|
     t.string :name
     t.integer :number
     t.text :content
     t.float :float
     t.boolean :active
   end

    create_table :other_primary_key_test_models, :primary_key => :other_id, :force => true do |t|
     t.string :name
     t.integer :number
     t.text :content
     t.float :float
     t.boolean :active
   end
end