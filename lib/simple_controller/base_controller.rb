class SimpleController::BaseController < ::InheritedResources::Base
  include Pundit::Authorization
  include SimpleController::GroupIndex

  self.responder = SimpleController::Responder
  respond_to :json

  rescue_from Pundit::NotAuthorizedError do |e|
    render json: { error: e.message }, status: 403
  end

  def list_index
    index!
  end

  def index
    index!
  end

  def show
    show!
  end

  def create
    create!
  end

  def update
    update!
  end

  def index!(options = {}, &block)
    options = { template: "#{response_view_path}/index" }.merge options
    super(options, &block)
  end

  def show!(options = {}, &block)
    options = { template: "#{response_view_path}/show" }.merge options
    super(options, &block)
  end

  def create!(options = {}, &block)
    options = { template: "#{response_view_path}/show", status: 201 }.merge options
    super(options, &block)
  end

  def update!(options = {}, &block)
    # 可以传入resource_params进行方法复用
    _resource_params = options.delete(:resource_params)
    _update_params = _resource_params.present? ? [_resource_params] : resource_params
    options = { template: "#{response_view_path}/show", status: 201 }.merge options

    object = resource

    options[:location] ||= smart_resource_url if update_resource(object, _update_params)

    respond_with_dual_blocks(object, options, &block)
  end

  def update_resource(object, attributes)
    new_type = attributes&.first&.dig(object.class.inheritance_column)

    if new_type.present?
      object.type = new_type
      object = object.becomes!(new_type.constantize)
    end

    super(object, attributes)
  end

  def batch_destroy
    collection.transaction do
      params[:ids].each do |id|
        collection.find(id).destroy!
      end
    end
  end

  def batch_create
    success_count = 0
    error_count = 0
    if params[:transition]
      collection.transition do
        batch_create_params.each do |resource_params|
          collection.create!(*resource_params)
          success_count += 1
        end
      end
    else
      batch_create_params.each do |resource_params|
        collection.create!(*resource_params)
        success_count += 1
      rescue StandardError
        error_count += 1
      end
    end
    render json: { success_count: success_count, error_count: error_count }, status: 201
  end

  def batch_update
    success_count = 0
    error_count = 0
    if params[:transition]
      collection.transition do
        collection.where(id: params[:ids]).update!(*resource_params)
      end
      success_count = collection.count
    else
      collection.where(id: params[:ids]).find_each do |_resource|
        _resource.update!(*resource_params)
        success_count += 1
      rescue StandardError
        error_count += 1
      end
    end
    render json: { success_count: success_count, error_count: error_count }, status: 201
  end

  protected

  def response_view_path
    if params[:ta_templates].present? && defined?(Forms::Template)
      'ta_records'
    else
      self.class.view_path
    end
  end

  class << self
    attr_reader :view_path

    # 查找template的时候，能够查找到
    def local_prefixes
      @view_path.present? ? super.unshift(@view_path) : super
    end

    def defaults(options)
      view_path = options.delete(:view_path)
      @ransack_off = options.delete(:ransack_off)
      @order_off = options.delete(:order_off)
      @paginate_off = options.delete(:paginate_off)
      @distinct_off = options.delete(:distinct_off)
      @policy_class = options.delete(:policy_class) || name.sub(/Controller$/, 'Policy').safe_constantize
      @database_policy = name.sub(/Controller$/, 'DatabasePolicy')
      _importable_class = options.delete(:importable_class)
      _exportable_class = options.delete(:exportable_class)

      set_view_path view_path if view_path.present?
      super(options)

      unless method_defined? :importable_class
        class_attribute :importable_class, instance_writer: false
        self.importable_class =
          _importable_class ||
            (name.sub(/Controller$/, 'Excel::Import').safe_constantize && name.sub(/Controller$/, 'Excel').safe_constantize) ||
            ("#{excel_class_name}::Import".safe_constantize && excel_class_name.safe_constantize) ||
            resource_class
      end

      return if method_defined? :exportable_class

      class_attribute :exportable_class, instance_writer: false

      self.exportable_class =
        _exportable_class ||
          (name.sub(/Controller$/, 'Excel::Export').safe_constantize && name.sub(/Controller$/, 'Excel').safe_constantize) ||
          ("#{excel_class_name}::Export".safe_constantize && excel_class_name.safe_constantize) ||
          resource_class
    end

    def excel_class_name
      return name if resource_class.blank?

      unless @excel_class_name.present?
        resource_class_name_arr = resource_class.name.split('::')
        @excel_class_name = if resource_class_name_arr.size > 1
                              resource_class_name_arr.insert(1, 'Excel').join('::')
                            else
                              resource_class_name_arr.insert(0, 'Excel').join('::')
                            end
      end
      @excel_class_name
    end

    def set_view_path(path)
      @view_path = path
    end
  end

  def respond_resource(options: {})
    options = { template: "#{response_view_path}/show", status: 201 }.merge options
    respond_with(*with_chain(resource), options)
  end

  def respond_collection(options: {})
    options = { template: "#{response_view_path}/index" }.merge options
    respond_with(*with_chain(collection), options)
  end

  # 对于resource的相关操作，都调用policy进行authorize
  def set_resource_ivar(resource)
    parent_objects = symbols_for_association_chain.each_with_object({}) do |sym, h|
      h[sym.to_sym] = instance_variable_get("@#{sym}")
    end
    policy_info = {
      record: resource,
      klass: resource_class,
      context: params,
      parents: parent_objects,
    }
    authorize_if_database_policy policy_info, "#{action_name}?"
    authorize_if_policy_class policy_info, "#{action_name}?"
    instance_variable_set("@#{resource_instance_name}", resource)
    @ta_record = resource
  end

  def set_collection_ivar(collection)
    parent_objects = symbols_for_association_chain.each_with_object({}) do |sym, h|
      h[sym.to_sym] = instance_variable_get("@#{sym}")
    end
    policy_info = {
      collection: collection,
      klass: resource_class,
      context: params,
      parents: parent_objects,
    }
    authorize_if_database_policy policy_info, "#{action_name}?"
    authorize_if_policy_class policy_info, "#{action_name}?"
    instance_variable_set("@#{resource_collection_name}", collection)
    @ta_records = collection
  end

  def association_chain
    @association_chain ||=
      symbols_for_association_chain.inject([begin_of_association_chain]) do |chain, symbol|
        parent_instance = evaluate_parent(symbol, resources_configuration[symbol], chain.last)
        # policy parent
        parent_config = resources_configuration[symbol]
        authorize_if_policy_class parent_instance, "parent_#{parent_config[:instance_name]}?"
        chain << parent_instance
      end.compact.freeze
  end

  def view_path
    self.class.instance_variable_get(:@view_path) ||
      self.class.instance_variable_set(:@view_path, extract_view_path)
  end

  def extract_view_path
    controller_class_path = controller_path.split '/'
    if controller_class_path.size > 1
      File.join controller_class_path[0], controller_class_path[-1]
    else
      controller_class_path[-1]
    end
  end

  # 可以进行继承实现
  def after_association_chain(association)
    association
  end

  # 这个方法为了兼容之前的，后面是可以废弃的
  # 执行sub_q
  def ransack_paginate(association)
    if params[:group_keys].present?
      statistics_association = association.unscope(:order).distinct
      if defined?(Com::CounterStorage) && Array(params[:group_keys]).count > 1
        hash = statistics_association.group(params[:group_keys]).count.merge(count: statistics_association.count)
        @statistics = Com::CounterStorage.load(params[:group_keys], hash, enum_dics: params[:enum_dics]&.to_unsafe_h || {}).group_sum(*params[:group_keys], include_sum: true)
      else
        @statistics = statistics_association.group(params[:group_keys]).count.merge(count: statistics_association.count)
      end
    end

    association = ransack_association(association, params[:q]) unless self.class.instance_variable_get(:@ransack_off) || params[:q].blank?
    association = ransack_association(association, params[:sub_q]) unless self.class.instance_variable_get(:@ransack_off) || params[:sub_q].blank?
    association = association.distinct unless self.class.instance_variable_get(:@distinct_off) || !association.respond_to?(:distinct) || !active_record? || params[:distinct_off].present?
    association = association.paginate(page: params[:page], per_page: params[:per_page]) unless self.class.instance_variable_get(:@paginate_off)
    association
  end

  alias origin_end_of_association_chain end_of_association_chain

  def database_policy_association_chain
    policy_class ||= self.class.instance_variable_get(:@database_policy)
    if policy_class.present? &&
      (scope_policy_class = "#{policy_class}::Scope".safe_constantize) &&
      origin_end_of_association_chain.is_a?(ActiveRecord::Relation)
      parent_objects = symbols_for_association_chain.each_with_object({}) do |sym, h|
        h[sym.to_sym] = instance_variable_get("@#{sym}")
      end
      scope_policy_class.new(current_user, policy_association_chain, **parent_objects).resolve
    else
      origin_end_of_association_chain.respond_to?(:all) ?
        origin_end_of_association_chain.all : origin_end_of_association_chain
    end
  end

  def policy_association_chain
    policy_class ||= self.class.instance_variable_get(:@policy_class)
    if policy_class.present? &&
      (scope_policy_class = "#{policy_class}::Scope".safe_constantize) &&
      origin_end_of_association_chain.is_a?(ActiveRecord::Relation)
      parent_objects = symbols_for_association_chain.each_with_object({}) do |sym, h|
        h[sym.to_sym] = instance_variable_get("@#{sym}")
      end
      scope_policy_class.new(current_user, origin_end_of_association_chain, **parent_objects).resolve
    else
      origin_end_of_association_chain.respond_to?(:all) ?
        origin_end_of_association_chain.all : origin_end_of_association_chain
    end
  end

  # ransack q, 这里主要是为了统计
  def query_association_chain
    if self.class.instance_variable_get(:@ransack_off) || params[:q].blank?
      database_policy_association_chain
      # policy_association_chain
    else
      ransack_association(database_policy_association_chain, params[:q])
    end
  end

  def end_of_association_chain
    query_association_chain
  end

  def after_of_association_chain
    after_association_chain(end_of_association_chain)
  end

  def collection_of_association_chain
    after_of_association_chain
  end

  # 执行统计和sub_q
  def ransack_association_chain
    association = collection_of_association_chain
    if params[:group_keys].present? && active_record?
      statistics_association = association.unscope(:order).distinct
      if defined?(Com::CounterStorage) && Array(params[:group_keys]).count > 1
        hash = statistics_association.group(params[:group_keys]).count.merge(count: statistics_association.count)
        @statistics = Com::CounterStorage.load(params[:group_keys], hash, enum_dics: params[:enum_dics]&.to_unsafe_h || {}).group_sum(*params[:group_keys], include_sum: true)
      else
        @statistics = statistics_association.group(params[:group_keys]).count.merge(count: statistics_association.count)
      end
    end

    if defined?(Com::Attr::Stat::Collection) && params[:collection_stat_condition].present?
      # 支持collection_stat_condition
      statistics_association = association.unscope(:order).distinct
      stat_condition = Com::Attr::Stat::Collection.new params.to_unsafe_h[:collection_stat_condition]
      @statistics = statistics_association.ta_statistic(stat_condition)
    end

    @resource_stat_condition = Com::Attr::Stat::Resource.new params.to_unsafe_h[:resource_stat_condition] if defined?(Com::Attr::Stat::Resource) && params[:resource_stat_condition].present?

    association = ransack_association(association, params[:sub_q]) unless self.class.instance_variable_get(:@ransack_off) || params[:sub_q].blank?
    # 增加默认id排序
    association = association.order(id: :desc) if association.respond_to?(:order) && !self.class.instance_variable_get(:@order_off)
    # distinct处理
    association = association.distinct unless self.class.instance_variable_get(:@distinct_off) || !association.respond_to?(:distinct) || !active_record? || params.dig(:q,
                                                                                                                                                                       :jorder,).present? || params[:distinct_off].present?
    association
  end

  def paginate_association_chain
    association = ransack_association_chain
    association = association.paginate(page: params[:page], per_page: params[:per_page]) unless self.class.instance_variable_get(:@paginate_off)
    association
  end

  def collection
    get_collection_ivar || set_collection_ivar(
      paginate_association_chain,
    )
  end

  def permitted_params
    action_resource_params_method_name = "#{params[:action]}_#{resource_params_method_name}"
    respond_to?(action_resource_params_method_name, true) ?
      { resource_request_name => send(action_resource_params_method_name) } :
      { resource_request_name => send(resource_params_method_name) }
  rescue ActionController::ParameterMissing
    # typically :new action
    raise unless params[:action].to_s == 'new'

    { resource_request_name => {} }
  end

  private

  def authorize_if_database_policy(record, query)
    policy_name = self.class.instance_variable_get(:@database_policy)
    database_policy = policy_name&.safe_constantize
    database_policy&.method_defined?(query) ?
      authorize(record, query, policy_class: database_policy) :
      record
  end

  def authorize_if_policy_class(record, query, policy_class: nil)
    policy_class ||= self.class.instance_variable_get(:@policy_class)
    policy_class&.method_defined?(query) ?
      authorize(record, query, policy_class: policy_class) :
      record
  end

  def active_record?
    self.class.resource_class < ActiveRecord::Base
  end

  def ransack_association(association, query_params)
    query_params = query_params.to_unsafe_h if query_params.present?
    # scopes，代表前端直接调用后台的scope过滤
    # scopes item如果是hash，则 key: scope名称 value: 转成symbolize keys
    if query_params[:scopes].present?
      association = Array.wrap(query_params[:scopes]).reduce(association) do |_association, _scope|
        _scope.is_a?(Hash) ?
          _scope.symbolize_keys.reduce(_association) { |_scope_association, (k, v)| method_invoke(_scope_association, k, v) } :
          _association.send(_scope)
      end
    end

    if active_record?
      association = association.ransack(query_params.except(:scopes, :refs, :jorder)).result
      # PG，为了支持distinct和order的操作，需要增加refs，手动includes 和 joins
      if query_params[:refs].present?
        _refs = Array(query_params[:refs]).map(&:to_sym)
        association = association.includes(*_refs).joins(*_refs)
      end
      if query_params.dig(:jorder).present?
        order_array = Array(query_params.dig(:jorder))
        sql = order_array.map do |order_string|
          _attr, _order = order_string.split(' ')
          _jsonb_attr = _attr.split('.').map.with_index { |a, index| index == 0 ? a : "'#{a}'" }.join('->')
          "#{_jsonb_attr} #{_order}"
        end.join(', ')
        association = association.order(Arel.sql(sql))
      end
    else
      _params = query_params.clone.except(:scopes)
      order_params = _params.delete(:s)
      selector = RansackMongo::Query.parse(_params)
      association = order_params.present? ?
                      association.where(selector).order(*Array(order_params)) : association.where(selector)
    end
    association
  end

  def method_invoke(record, subject, args)
    subject_arity = record.__send__(:method, subject.to_sym).arity

    return record.__send__(subject) if subject_arity.zero?

    if subject_arity < 0
      if args.is_a?(Hash)
        return record.__send__(subject, **args.symbolize_keys)
      elsif args.is_a?(Array)
        return record.__send__(subject, *args)
      else
        return record.__send__(subject, args)
      end
    end

    arg_arity = subject_parameters.select { |p| !p.first.to_s.start_with?('key') }.count
    key_arity = subject_arity - arg_arity

    _args = if arg_arity > 0
              args.is_a?(Array) ? args[0..(arg_arity - 1)] : [args][0..(arg_arity - 1)]
            else
              []
            end
    _keys = if key_arity > 0
              args.is_a?(Array) ? args[arg_arity..(subject_arity - 1)].to_h : args
            else
              {}
            end

    record.__send__(subject, *_args, **_keys.symbolize_keys)
  end
end
