json.current_page @<%= resource_plural %>.current_page
json.total_pages @<%= resource_plural %>.total_pages
json.total_count @<%= resource_plural %>.count
json.statistic @statistic if @statistic.present?

json.records @<%= resource_plural %>, partial: '<%= view_path %>/simple', as: :<%= resource_singular %>
