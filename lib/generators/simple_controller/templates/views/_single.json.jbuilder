<%- if active_record? -%>
json.extract!(
  <%= resource_singular %>,
  *<%= resource_singular %>.class.try(:extra_view_attributes, 'single'),
  :id,
  :created_at,
  :updated_at,
  <%- single_attribute_names.each do |attribute_name| -%>
  :<%= attribute_name %>,
  <%- end -%>
)
<%- else -%>
json.merge! <%= resource_singular %>.as_json
<%- end -%>
