json.partial! '<%= view_path %>/simple', <%= resource_singular %>: <%= resource_singular %>

<%- if detail_attribute_names.present? -%>
json.extract!(
  <%= resource_singular %>,
  <%- detail_attribute_names.each do |attribute_name| -%>
  :<%= attribute_name %>,
  <%- end -%>
)
<%- end -%>
