<%- if active_record? -%>
json.extract!(
  <%= resource_singular %>,
  :id,
  :created_at,
  :updated_at,
  <%- attributes_names.each do |attribute_name| -%>
  :<%= attribute_name %>,
  <%- end -%>
  *<%= resource_singular %>.class.try(:extra_permitted_attributes),
)
<%- else -%>
json.merge! <%= resource_singular %>.as_json
<%- end -%>
