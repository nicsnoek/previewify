ActiveRecord::Base.connection.tables.each {|table_name| ActiveRecord::Base.connection.drop_table table_name }
