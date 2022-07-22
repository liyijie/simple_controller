json.current_page @<%= resource_plural %>.current_page
json.total_pages @<%= resource_plural %>.total_pages
json.total_count @<%= resource_plural %>.total_entries
json.statistics @statistics if @statistics.present?

json.records @<%= resource_plural %>, partial: 'simple', as: :<%= resource_singular %>
