json.partial! '<%= view_path %>/simple', <%= resource_singular %>: <%= resource_singular %>
json.extract!(
  <%= resource_singular %>,
  *<%= resource_singular %>.class.try(:extra_view_attributes, 'detail'),
)

<%- if detail_attribute_names.present? -%>
json.extract!(
  <%= resource_singular %>,
  <%- detail_attribute_names.each do |attribute_name| -%>
  :<%= attribute_name %>,
  <%- end -%>
)
<%- end -%>
