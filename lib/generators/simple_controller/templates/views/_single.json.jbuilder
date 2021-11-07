json.extract!(
  <%= resource_singular %>,
  :id,
  :created_at,
  :updated_at,
  <%- attributes_names.each do |attribute_name| -%>
  :<%= attribute_name %>,
  <%- end -%>
)
