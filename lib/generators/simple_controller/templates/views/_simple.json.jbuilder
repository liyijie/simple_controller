json.partial! '<%= view_path %>/single', <%= resource_singular %>: <%= resource_singular %>
json.extract!(
  <%= resource_singular %>,
  *<%= resource_singular %>.class.try(:extra_view_attributes, 'simple'),
)

<%- belongs_to_refs.each do |ref| -%>
json.<%= ref.name.to_s %> <%= resource_singular %>.<%= ref.name.to_s %>, partial: '<%= File.join(ref.klass.name.underscore.pluralize, 'single') %>', as: :<%= ref.name %>
<%- end -%>
