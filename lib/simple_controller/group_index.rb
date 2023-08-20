module SimpleController::GroupIndex
  def group_index
    keys = Array(params[:q]&.[](:group_keys) || [])
    # keys = ["priority", "own_tokens_user_of_User_type_name", "state"]

    ransack_options = keys.reduce({}) do |options, key|
      options.merge("#{key}_eq": "some thing")
    end
    search = collection.ransack(ransack_options)
    group_configs = search.base.values.map do |ransack_condition|
      arel = ransack_condition.arel_predicate
      group_key = [arel.left.relation.name, arel.left.name].join('.')
      {
        group_key: group_key,
        ransack_key: ransack_condition.key,
      }
    end

    group_keys = group_configs.map { |config| config[:group_key] }
    statistics = search.object.group(group_keys).count

    process_statistics_key = proc do |ary, i|
      result = ary.group_by { |key| key[key.length - i - 1] }
      if (i - 1).positive?
        (result.map do |k, v|
          [k, process_statistics_key.call(v, i - 1)]
        end).to_h
      else
        result
      end
    end

    # {
    #   nil=>
    #     {
    #       "戴华杰"=>[[nil, "戴华杰", "starting"], [nil, "戴华杰", "pending"], [nil, "戴华杰", "completed"]],
    #       nil=>[[nil, nil, "completed"], [nil, nil, "terminated"], [nil, nil, "starting"], [nil, nil, "pending"]],
    #       "张祥"=>[[nil, "张祥", "completed"]],
    #     },
    #   "A"=>{nil=>[["A", nil, "pending"]], "李龙贺"=>[["A", "李龙贺", "pending"]]},
    #   "C"=>{nil=>[["C", nil, "completed"]]},
    #   "B"=>{nil=>[["B", nil, "pending"]]}
    # }
    tree_result = process_statistics_key.call(statistics.keys, keys.size - 1)
    data = tree_result_mount_data(tree_result, statistics, group_configs)

    render json: { current_page: 1, total_pages: 1,total_count: data.count, records: data }, status: 200
  end

  def tree_result_mount_data(tree_result, statistics, group_configs, depth=0)
    (tree_result || []).map do |key, value|
      children =
        if value.is_a?(Hash)
          tree_result_mount_data(value, statistics, group_configs, depth + 1)
        elsif value.is_a?(Array)
          fake_tree_result = value.map { |ary_key| [ary_key.last, [ary_key]] }.to_h
          if fake_tree_result == tree_result
            []
          else
            tree_result_mount_data(
              fake_tree_result,
              statistics,
              group_configs,
              depth + 1
            )
          end
        else
          []
        end
      {
        count: tree_result_get_count_sum(value, statistics),
        children: children,
      }.merge(
        key.nil? ? {
          ransack_key: (group_configs[depth] || group_configs.last)[:ransack_key].gsub(/_eq$/, '_null'),
          ransack_value: true,
        } : {
          ransack_key: (group_configs[depth] || group_configs.last)[:ransack_key],
          ransack_value: key,
        }
      )
    end
  end

  def tree_result_get_count_sum(tree_result, statistics)
    if tree_result.is_a?(Hash)
      tree_result.reduce(0) do |sum, (k, v)|
        sum + tree_result_get_count_sum(v, statistics)
      end
    elsif tree_result.is_a?(Array)
      tree_result.reduce(0) { |sum, key_ary| sum + statistics[key_ary].to_i }
    else
      0
    end
  end
end
