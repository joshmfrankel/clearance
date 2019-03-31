class AddClearanceTo<%= @model.pluralize %> < ActiveRecord::Migration<%= migration_version %>
  def self.up
    change_table :<%= @table_name %> do |t|
<% config[:new_columns].values.each do |column| -%>
      <%= column %>
<% end -%>
    end

<% config[:new_indexes].values.each do |index| -%>
    <%= index %>
<% end -%>

    user_models = select_all("SELECT id FROM <%= @table_name %> WHERE remember_token IS NULL")

    user_models.each do |user_model|
      update <<-SQL
        UPDATE <%= @table_name %>
        SET remember_token = '#{Clearance::Token.new}'
        WHERE id = '#{user_model['id']}'
      SQL
    end
  end

  def self.down
    change_table :<%= @table_name %> do |t|
<% if config[:new_columns].any? -%>
      t.remove <%= new_columns.keys.map { |column| ":#{column}" }.join(", ") %>
<% end -%>
    end
  end
end
