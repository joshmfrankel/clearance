require 'rails/generators/base'
require 'rails/generators/active_record'

module Clearance
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration
      source_root File.expand_path('../templates', __FILE__)

      DEFAULT_USER_MODEL = "User"
      class_option :model, type: :string, aliases: '-m', default: DEFAULT_USER_MODEL

      def create_clearance_initializer
        @model = model
        template('clearance.rb', 'config/initializers/clearance.rb')
      end

      def inject_clearance_into_application_controller
        inject_into_class(
          "app/controllers/application_controller.rb",
          ApplicationController,
          "  include Clearance::Controller\n"
        )
      end

      def create_or_inject_clearance_into_user_model
        model_filepath = "app/models/#{model.underscore}.rb"

        if File.exists?(model_filepath) && !File.readlines(model_filepath).grep(/include Clearance::User/).any?
          inject_into_file(
            model_filepath,
            "  include Clearance::User\n\n",
            after: "class #{model} < #{models_inherit_from}\n"
          )
        else
          @inherit_from = models_inherit_from
          @model = model
          template("user.rb.erb", model_filepath)
        end
      end

      def create_clearance_migration
        @table_name = table_name
        @model = model

        if table_exists?
          create_add_columns_migration
        else
          copy_migration 'db/migrate/create_users.rb', "./db/migrate/create_#{table_name}.rb"
        end
      end

      def display_readme_in_terminal
        readme 'README'
      end

      private

      def model
        @_model ||= options[:model].presence || DEFAULT_USER_MODEL
      end

      def table_name
        @_table_name ||= (options[:model].present? ? options[:model].demodulize.underscore.pluralize : DEFAULT_USER_MODEL.tableize)
      end

      def create_add_columns_migration
        if migration_needed?
          config = {
            new_columns: new_columns,
            new_indexes: new_indexes
          }

          copy_migration 'db/migrate/add_clearance_to_users.rb', "./db/migrate/add_clearance_to_#{table_name}.rb", config
        end
      end

      def copy_migration(source, destination, config = {})
        unless migration_exists?(destination)
          migration_template(
            source,
            destination,
            config.merge(migration_version: migration_version),
          )
        end
      end

      def migration_needed?
        new_columns.any? || new_indexes.any?
      end

      def new_columns
        @new_columns ||= {
          email: 't.string :email',
          encrypted_password: 't.string :encrypted_password, limit: 128',
          confirmation_token: 't.string :confirmation_token, limit: 128',
          remember_token: 't.string :remember_token, limit: 128'
        }.reject { |column| existing_table_columns.include?(column.to_s) }
      end

      def new_indexes
        @new_indexes ||= {
          "index_#{table_name}_on_email" => "add_index :#{table_name}, :email",
          "index_#{table_name}_on_remember_token" => "add_index :#{table_name}, :remember_token"
        }.reject { |index| existing_table_indexes.include?(index.to_s) }
      end

      def migration_exists?(name)
        existing_migrations.include?(name)
      end

      def existing_migrations
        @existing_migrations ||= Dir.glob("db/migrate/*.rb").map do |file|
          migration_name_without_timestamp(file)
        end
      end

      def migration_name_without_timestamp(file)
        file.sub(%r{^.*(db/migrate/)(?:\d+_)?}, '')
      end

      def table_exists?
        if ActiveRecord::Base.connection.respond_to?(:data_source_exists?)
          ActiveRecord::Base.connection.data_source_exists?(table_name)
        else
          ActiveRecord::Base.connection.table_exists?(table_name)
        end
      end

      def existing_table_columns
        ActiveRecord::Base.connection.columns(table_name).map(&:name)
      end

      def existing_table_indexes
        ActiveRecord::Base.connection.indexes(table_name).map(&:name)
      end

      # for generating a timestamp when using `create_migration`
      def self.next_migration_number(dir)
        ActiveRecord::Generators::Base.next_migration_number(dir)
      end

      def migration_version
        if Rails.version >= "5.0.0"
          "[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
        end
      end

      def models_inherit_from
        if Rails.version >= "5.0.0"
          "ApplicationRecord"
        else
          "ActiveRecord::Base"
        end
      end
    end
  end
end
