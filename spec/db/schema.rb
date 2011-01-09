ActiveRecord::Schema.define :version => 0 do

   create_table :test_models, :force => true do |t|
     t.string :name
     t.integer :number
     t.text :content
     t.float :float
     t.boolean :active
   end
end