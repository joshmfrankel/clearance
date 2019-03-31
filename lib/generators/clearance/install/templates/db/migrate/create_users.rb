class Create<%= @model %> < ActiveRecord::Migration<%= migration_version %>
  def change
    create_table :<%= @table_name %> do |t|
      t.timestamps null: false
      t.string :email, null: false
      t.string :encrypted_password, limit: 128, null: false
      t.string :confirmation_token, limit: 128
      t.string :remember_token, limit: 128, null: false
    end

    add_index :<%= @table_name %>, :email
    add_index :<%= @table_name %>, :remember_token
  end
end
