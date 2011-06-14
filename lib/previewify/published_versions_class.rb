module Previewify
  module ActiveRecord

    private

    def create_published_versions_class
      const_set(previewify_config.published_version_class_name, Class.new(self)).class_eval do

        private

        def self.setup_scope_to_default_to_latest
          default_scope :conditions => "#{previewify_config.published_flag_attribute_name} = true"
        end

        def self.make_attributes_read_only
          columns.each { |column|
            attr_readonly(column.name) unless column.name == previewify_config.published_flag_attribute_name
          }
        end

        public

        set_table_name(previewify_config.published_version_table_name)
        set_primary_key(previewify_config.published_version_primary_key_name)


        def self.perform_class_initialisation_that_requires_table_to_exist
          #If this setup can not run because the table does not exits yet, it must be run after the table is created.
          if connection.tables.include?(previewify_config.published_version_table_name)
            setup_scope_to_default_to_latest
            make_attributes_read_only
          end
        end

        def self.uninherit_preview_methods_for_published_attributes
        # Uninherit methods from the preview version that delegate to attributes of the published version
        # otherwise they will cause infinite recursion.
          undef_method(previewify_config.version_attribute_name)
          undef_method(previewify_config.published_on_attribute_name)
        end


        perform_class_initialisation_that_requires_table_to_exist()

        uninherit_preview_methods_for_published_attributes()

        if previewify_config.preview_only_method_names.present?
          previewify_config.preview_only_method_names.each do |preview_only_method|
            undef_method(preview_only_method)
          end
        end

        if previewify_config.published_only_method_names.present?
          previewify_config.published_only_method_names.each do |published_only_method|
            class_variable_set("@@#{published_only_method}_method", self.instance_method(published_only_method))
            define_method("#{published_only_method}") do |*args|
              self.class.class_variable_get("@@#{published_only_method}_method").bind(self).call(*args)
            end
          end
        end

        def take_down!
          update_attribute(previewify_config.published_flag_attribute_name, false)
        end

        def published_attributes
          attributes.reject { |key|
            previewify_config.published_version_metainformation_attributes.include?(key)
          }
        end

        def published?
          true
        end

        def has_unpublished_changes?
          false
        end

        def with_published_id
          @with_published_id = true
          return yield
        ensure
          @with_published_id = false
        end

        def id
          if @with_published_id
            send(previewify_config.published_version_primary_key_name)
          else
            send(previewify_config.mapped_primary_key_name)
          end
        end

        def save_with_published_id(*args)
          with_published_id do
            save_without_published_id(*args)
          end
        end

        alias_method_chain :save, :published_id

        def self.publish(preview, version)
          raise(RecordNotPublished) unless preview.valid?
          attributes_to_publish = preview.published_attributes
          attributes_to_publish.merge!(
                previewify_config.version_attribute_name => version,
              previewify_config.published_flag_attribute_name => true,
              previewify_config.published_on_attribute_name => Time.now
          )

          instance = self.new(attributes_to_publish)
          #primary key is never mass assigned, so do it separately:
          instance.send(previewify_config.mapped_primary_key_name.to_s+'=', attributes_to_publish[previewify_config.primary_key_name])
          instance.save || raise(RecordNotPublished)
          return instance
        end

        def self.take_down(pk_to_take_down)
          take_down_candidate = latest_published_by_primary_key(pk_to_take_down)
          take_down_candidate.try(:take_down!)
          return take_down_candidate
        end

        def self.latest_published_by_primary_key(primary_key_value)
          find(:first, :conditions => ["#{previewify_config.mapped_primary_key_name} = ?", primary_key_value])
        end

        def self.specific_version_by_primary_key(primary_key_value, version_number)
          with_exclusive_scope do
            find(:first, :conditions => ["#{previewify_config.mapped_primary_key_name} = ? AND #{previewify_config.version_attribute_name} = ?", primary_key_value, version_number])
          end
        end

        def self.all_versions_by_primary_key(primary_key_value)
          with_exclusive_scope do
            find(:all, :conditions => ["#{previewify_config.mapped_primary_key_name} = ?", primary_key_value])
          end
        end

      end

    end


  end
end