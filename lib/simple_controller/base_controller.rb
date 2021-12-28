class SimpleController::BaseController < ::InheritedResources::Base
  include Pundit

  self.responder = SimpleController::Responder
  respond_to :json

  rescue_from Pundit::NotAuthorizedError do |e|
    render json: { error: e.message }, status: 403
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

  def index!(options={}, &block)
    options = { template: "#{self.class.view_path}/index" }.merge options
    super(options, &block)
  end

  def show!(options={}, &block)
    options = { template: "#{self.class.view_path}/show" }.merge options
    super(options, &block)
  end

  def create!(options={}, &block)
    options = { template: "#{self.class.view_path}/show", status: 201 }.merge options
    super(options, &block)
  end

  def update!(options={}, &block)
    options = { template: "#{self.class.view_path}/show", status: 201 }.merge options
    super(options, &block)
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
        begin
          collection.create!(*resource_params)
          success_count += 1
        rescue
          error_count += 1
        end
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
        begin
          _resource.update!(*resource_params)
          success_count += 1
        rescue
          error_count += 1
        end
      end
    end
    render json: { success_count: success_count, error_count: error_count }, status: 201
  end

  protected

  class << self
    def view_path
      @view_path
    end

    # 查找template的时候，能够查找到
    def local_prefixes
      @view_path.present? ? super.unshift(@view_path) : super
    end

    def defaults(options)
      view_path = options.delete(:view_path)
      @ransack_off = options.delete(:ransack_off)
      @paginate_off = options.delete(:paginate_off)
      @distinct_off = options.delete(:distinct_off)
      @policy_class = options.delete(:policy_class) || self.name.sub(/Controller$/, 'Policy').safe_constantize
      _importable_class = options.delete(:importable_class)
      _exportable_class = options.delete(:exportable_class)

      set_view_path view_path if view_path.present?
      super(options)

      unless self.method_defined? :importable_class
        self.class_attribute :importable_class, instance_writer: false
        self.importable_class =
          _importable_class ||
          (self.name.sub(/Controller$/, 'Excel::Import').safe_constantize && self.name.sub(/Controller$/, 'Excel').safe_constantize) ||
          self.resource_class
      end

      unless self.method_defined? :exportable_class
        self.class_attribute :exportable_class, instance_writer: false

        self.exportable_class =
          _exportable_class ||
          (self.name.sub(/Controller$/, 'Excel::Export').safe_constantize && self.name.sub(/Controller$/, 'Excel').safe_constantize) ||
          self.resource_class
      end

    end

    def set_view_path path
      @view_path = path
    end
  end

  def respond_resource(options: {})
    options = { template: "#{self.class.view_path}/show", status: 201 }.merge options
    respond_with(*with_chain(resource), options)
  end

  def respond_collection(options: {})
    options = { template: "#{self.class.view_path}/index" }.merge options
    respond_with(*with_chain(collection), options)
  end


  # 对于resource的相关操作，都调用policy进行authorize
  def set_resource_ivar(resource)
    _resource = authorize_if_policy_class resource, "#{action_name}?"
    instance_variable_set("@#{resource_instance_name}", _resource)
  end

  def set_collection_ivar(collection)
    authorize_if_policy_class resource_class, "#{action_name}?"
    instance_variable_set("@#{resource_collection_name}", collection)
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
    controller_class_path = controller_path.split "/"
    if controller_class_path.size > 1
      File.join controller_class_path[0], controller_class_path[-1]
    else
      controller_class_path[-1]
    end
  end

  # 可以进行继承实现
  def after_association_chain association
    association
  end

  # 这个方法为了兼容之前的，后面是可以废弃的
  # 执行sub_q
  def ransack_paginate(association)
    if params[:group_keys].present?
      statistics_association = association.unscope(:order).distinct
      if defined?(Com::CounterStorage) && Array(params[:group_keys]).count > 1
        hash = statistics_association.group(params[:group_keys]).count.merge(count: statistics_association.count)
        @statistics = Com::CounterStorage.load(params[:group_keys], hash, params[:enum_dics]&.to_unsafe_h || {}).group_sum(*params[:group_keys])
      else
        @statistics = statistics_association.group(params[:group_keys]).count.merge(count: statistics_association.count)
      end
    end

    association = association.ransack(params[:q]).result unless self.class.instance_variable_get(:@ransack_off) || params[:q].blank?
    association = association.ransack(params[:sub_q]).result unless self.class.instance_variable_get(:@ransack_off) || params[:sub_q].blank?
    association = association.distinct unless self.class.instance_variable_get(:@distinct_off) || !association.respond_to?(:distinct)
    association = association.paginate(page: params[:page], per_page: params[:per_page]) unless self.class.instance_variable_get(:@paginate_off)
    association
  end

  alias_method :origin_end_of_association_chain, :end_of_association_chain

  def policy_association_chain
    policy_class ||= self.class.instance_variable_get(:@policy_class)
    if policy_class.present? &&
        (scope_policy_class = "#{policy_class}::Scope".safe_constantize) &&
        origin_end_of_association_chain.is_a?(ActiveRecord::Relation)
      scope_policy_class.new(current_user, origin_end_of_association_chain).resolve
    else
      origin_end_of_association_chain
    end
  end

  # ransack q, 这里主要是为了统计
  def query_association_chain
    if self.class.instance_variable_get(:@ransack_off) || params[:q].blank?
      policy_association_chain
    else
      policy_association_chain.ransack(params[:q]).result
    end
  end

  def end_of_association_chain
    query_association_chain
  end

  def after_of_association_chain
    after_association_chain(end_of_association_chain)
  end

  def collection_of_association_chain
     _association_chain = after_of_association_chain
    if _association_chain.respond_to?(:order)
      _association_chain.order(id: :desc)
    else
      _association_chain
    end
  end

  # 执行统计和sub_q
  def ransack_association_chain
    association = collection_of_association_chain
    if params[:group_keys].present?
      statistics_association = association.unscope(:order).distinct
      if defined?(Com::CounterStorage) && Array(params[:group_keys]).count > 1
        hash = statistics_association.group(params[:group_keys]).count.merge(count: statistics_association.count)
        @statistics = Com::CounterStorage.load(params[:group_keys], hash, params[:enum_dics]&.to_unsafe_h || {}).group_sum(*params[:group_keys])
      else
        @statistics = statistics_association.group(params[:group_keys]).count.merge(count: statistics_association.count)
      end
    end

    association = association.ransack(params[:sub_q]).result unless self.class.instance_variable_get(:@ransack_off) || params[:sub_q].blank?
    association = association.ransack(params[:q]).result unless self.class.instance_variable_get(:@ransack_off) || params[:q].blank?
    association = association.distinct unless self.class.instance_variable_get(:@distinct_off) || !association.respond_to?(:distinct)
    association
  end

  def paginate_association_chain
    association = ransack_association_chain
    association = association.paginate(page: params[:page], per_page: params[:per_page]) unless self.class.instance_variable_get(:@paginate_off)
    association
  end

  def collection
    get_collection_ivar || set_collection_ivar(
      paginate_association_chain
    )
  end

  def permitted_params
    action_resource_params_method_name = "#{params[:action]}_#{resource_params_method_name}"
    respond_to?(action_resource_params_method_name, true) ?
      {resource_request_name => send(action_resource_params_method_name)} :
      {resource_request_name => send(resource_params_method_name)}
  rescue ActionController::ParameterMissing
    # typically :new action
    if params[:action].to_s == 'new'
      {resource_request_name => {}}
    else
      raise
    end
  end

  private

  def authorize_if_policy_class record, query, policy_class: nil
    policy_class ||= self.class.instance_variable_get(:@policy_class)
    policy_class&.method_defined?(query) ?
       authorize(record, query, policy_class: policy_class) :
       record
  end
end
